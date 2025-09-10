require 'rails_helper'

# This test protects the CRITICAL distance calculation business logic that determines
# which schools users see based on their location. The Haversine formula calculation
# is the CORE of the app's value proposition - showing nearby schools to parents.
# Without accurate distance calculations, users would see wrong schools, breaking the
# entire user experience. This test ensures the distance math remains accurate.

RSpec.describe 'School Distance Calculation Business Logic', type: :model do
  describe 'Haversine distance calculation - Core business feature' do
    it 'correctly calculates distances and filters schools for user location searches' do
      # Clear existing schools to ensure test isolation
      School.delete_all
      Place.delete_all

      # PART 1: Create schools at known distances from a reference point
      # Reference location: Central Bangkok (CentralWorld)
      reference_lat = 13.7468
      reference_lng = 100.5392

      # School exactly at reference point (0 km)
      same_location_school = create(:school, name: 'Same Location School')
      same_location_school.place.update!(lat: reference_lat, lng: reference_lng)

      # School ~1.11 km north (0.01 degrees latitude difference)
      one_km_north_school = create(:school, name: '1km North School')
      one_km_north_school.place.update!(lat: reference_lat + 0.01, lng: reference_lng)

      # School ~11.1 km east (0.1 degrees longitude difference at this latitude)
      eleven_km_east_school = create(:school, name: '11km East School')
      eleven_km_east_school.place.update!(lat: reference_lat, lng: reference_lng + 0.1)

      # School ~15.7 km northeast (diagonal distance)
      diagonal_school = create(:school, name: '15km Diagonal School')
      diagonal_school.place.update!(lat: reference_lat + 0.1, lng: reference_lng + 0.1)

      # School ~111 km north (1 degree latitude difference)
      far_north_school = create(:school, name: '111km North School')
      far_north_school.place.update!(lat: reference_lat + 1.0, lng: reference_lng)

      # School on opposite side of Bangkok (~50 km away)
      far_school = create(:school, name: 'Far Bangkok School')
      far_school.place.update!(lat: 13.5, lng: 100.3)

      # PART 2: Test exact distance calculations

      # Same location should be 0 km
      distance = School.calculate_haversine_distance(
        reference_lat, reference_lng,
        same_location_school.place.lat, same_location_school.place.lng
      )
      expect(distance).to eq(0.0)

      # 0.01 degree latitude = ~1.11 km
      distance = School.calculate_haversine_distance(
        reference_lat, reference_lng,
        one_km_north_school.place.lat, one_km_north_school.place.lng
      )
      expect(distance).to be_between(1.0, 1.2)

      # 0.1 degree longitude at this latitude = ~10.8 km
      distance = School.calculate_haversine_distance(
        reference_lat, reference_lng,
        eleven_km_east_school.place.lat, eleven_km_east_school.place.lng
      )
      expect(distance).to be_between(10.7, 10.9)

      # Diagonal distance should follow Pythagorean-like calculation on sphere
      distance = School.calculate_haversine_distance(
        reference_lat, reference_lng,
        diagonal_school.place.lat, diagonal_school.place.lng
      )
      expect(distance).to be_between(15.5, 15.9)

      # 1 degree latitude = ~111 km
      distance = School.calculate_haversine_distance(
        reference_lat, reference_lng,
        far_north_school.place.lat, far_north_school.place.lng
      )
      expect(distance).to be_between(110.5, 111.5)

      # PART 3: Test the with_distance scope (business-critical filtering)

      # Search within 2 km - should find 2 schools
      nearby_schools = School.with_distance(reference_lat, reference_lng, 2)
      expect(nearby_schools.map(&:name)).to contain_exactly(
        'Same Location School', '1km North School'
      )

      # Search within 12 km - should find 3 schools
      medium_schools = School.with_distance(reference_lat, reference_lng, 12)
      expect(medium_schools.map(&:name)).to contain_exactly(
        'Same Location School', '1km North School', '11km East School'
      )

      # Search within 20 km - should find 4 schools
      wider_schools = School.with_distance(reference_lat, reference_lng, 20)
      expect(wider_schools.map(&:name)).to contain_exactly(
        'Same Location School', '1km North School', '11km East School', '15km Diagonal School'
      )

      # Search within 60 km - should find 5 schools (excluding the 111km one)
      citywide_schools = School.with_distance(reference_lat, reference_lng, 60)
      expect(citywide_schools.map(&:name)).to include('Far Bangkok School')
      expect(citywide_schools.map(&:name)).not_to include('111km North School')

      # PART 4: Verify distance ordering (critical for user experience)

      schools_ordered = School.with_distance(reference_lat, reference_lng, 20)
      distances = schools_ordered.map(&:distance_km)

      # Distances should be in ascending order
      expect(distances).to eq(distances.sort)

      # First school should be closest
      expect(schools_ordered.first.name).to eq('Same Location School')
      expect(schools_ordered.first.distance_km).to eq(0.0)

      # PART 5: Test edge cases that could break user experience

      # Antipodal points (opposite sides of Earth) - max distance ~20,000 km
      max_distance = School.calculate_haversine_distance(
        0, 0,      # Equator, Prime Meridian
        0, 180     # Equator, International Date Line
      )
      expect(max_distance).to be_between(20000, 20040)

      # North to South pole - should be ~20,000 km (half Earth circumference)
      pole_distance = School.calculate_haversine_distance(
        90, 0,     # North Pole
        -90, 0     # South Pole
      )
      expect(pole_distance).to be_between(20000, 20040)

      # Crossing International Date Line
      date_line_distance = School.calculate_haversine_distance(
        35.6762, 139.6503,  # Tokyo
        37.7749, -122.4194  # San Francisco
      )
      expect(date_line_distance).to be_between(8200, 8300)

      # PART 6: Test with nil/missing coordinates (defensive programming)

      # School with no place
      create(:school, name: 'No Place School', place: nil)

      # Should not appear in distance queries
      results = School.with_distance(reference_lat, reference_lng, 1000)
      expect(results.map(&:name)).not_to include('No Place School')

      # The with_distance scope filters out schools with nil coordinates automatically
      # because it joins on places and requires lat/lng to be present for calculation

      # PART 7: Test pagination integration (critical for performance)

      # Create 30 schools within range
      30.times do |i|
        school = create(:school, name: "Pagination School #{i}")
        # Place them at slightly different distances
        school.place.update!(
          lat: reference_lat + (0.001 * i),
          lng: reference_lng
        )
      end

      # Get results - with_distance returns a Kaminari paginatable array
      results = School.with_distance(reference_lat, reference_lng, 5)

      # Verify it's a paginatable array
      expect(results).to be_a(Kaminari::PaginatableArray)

      # Get first page with 10 items
      first_page = results.page(1).per(10)
      expect(first_page.size).to eq(10)

      # Verify ordering is maintained across pages
      second_page = results.page(2).per(10)
      expect(first_page.last.distance_km).to be <= second_page.first.distance_km

      # PART 8: Test real-world Bangkok school locations

      # Simulate user in Sukhumvit area searching for schools
      sukhumvit_lat = 13.7307
      sukhumvit_lng = 100.5418

      # Create schools in actual Bangkok districts
      sathorn_school = create(:school, name: 'Sathorn International')
      sathorn_school.place.update!(lat: 13.7189, lng: 100.5235) # ~2km

      silom_school = create(:school, name: 'Silom Academy')
      silom_school.place.update!(lat: 13.7277, lng: 100.5265) # ~1.6km

      thonburi_school = create(:school, name: 'Thonburi School')
      thonburi_school.place.update!(lat: 13.7205, lng: 100.4765) # ~7km

      # Parent searches within 3km of Sukhumvit
      local_results = School.with_distance(sukhumvit_lat, sukhumvit_lng, 3)
      local_names = local_results.map(&:name)

      # Should find Sathorn and Silom but not Thonburi
      expect(local_names).to include('Sathorn International', 'Silom Academy')
      expect(local_names).not_to include('Thonburi School')

      # Verify the distance calculation for Thonburi school
      thonburi_distance = School.calculate_haversine_distance(
        sukhumvit_lat, sukhumvit_lng,
        thonburi_school.place.lat, thonburi_school.place.lng
      )
      expect(thonburi_distance).to be_between(7.0, 7.2)
    end

    it 'handles special coordinate edge cases without breaking' do
      # Test coordinates at boundaries (180 and -180 are the same longitude)
      # Due to floating point precision, expect very small distance near 0
      expect(School.calculate_haversine_distance(90, 180, 90, -180)).to be < 0.0001
      expect(School.calculate_haversine_distance(-90, 0, -90, 180)).to be < 0.0001

      # Test with very small differences (micrometers)
      tiny_distance = School.calculate_haversine_distance(
        13.7563, 100.5018,
        13.7563000001, 100.5018000001
      )
      expect(tiny_distance).to be < 0.001 # Less than 1 meter

      # Test with negative coordinates (Southern/Western hemispheres)
      sydney_rio_distance = School.calculate_haversine_distance(
        -33.8688, 151.2093,  # Sydney
        -22.9068, -43.1729   # Rio de Janeiro
      )
      expect(sydney_rio_distance).to be_between(13500, 13600)
    end
  end
end
