require 'rails_helper'

# This test protects the critical school filtering functionality that users depend on
# to find schools near their location. It ensures distance calculations, pagination,
# and filtering logic work correctly - preventing regressions when AI coders modify
# the SchoolsController#filtered action or underlying business logic.

RSpec.describe 'Schools Filtered Endpoint', type: :request do
  describe 'GET /schools/filtered' do
    # Create test schools at various distances from Bangkok center
    let!(:very_close_school) do
      create(:school, name: 'Very Close School') do |school|
        school.place.update!(lat: 13.7563, lng: 100.5018) # ~0km from center
      end
    end

    let!(:nearby_school) do
      create(:school, name: 'Nearby School') do |school|
        school.place.update!(lat: 13.8000, lng: 100.5500) # ~5-6km from center
      end
    end

    let!(:medium_distance_school) do
      create(:school, name: 'Medium Distance School') do |school|
        school.place.update!(lat: 13.9000, lng: 100.6000) # ~18-20km from center
      end
    end

    let!(:far_school) do
      create(:school, name: 'Far School') do |school|
        school.place.update!(lat: 14.0000, lng: 100.8000) # ~35-40km from center
      end
    end

    let!(:very_far_school) do
      create(:school, name: 'Very Far School') do |school|
        school.place.update!(lat: 14.5000, lng: 101.5000) # ~100+ km from center
      end
    end

    let!(:draft_school) do
      create(:school, :draft, name: 'Draft School') do |school|
        school.place.update!(lat: 13.7563, lng: 100.5018) # Same location as very_close
      end
    end

    # User's home location (Bangkok center)
    let(:home_location) { { home_lat: 13.7563, home_lng: 100.5018 } }

    it 'successfully filters schools within specified radius and returns expected data structure' do
      # Test with 10km radius - should include very_close and nearby schools only
      get filtered_schools_path, params: home_location.merge(radius: 10), as: :json

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)

      # Verify response structure
      expect(json).to have_key('schools')
      expect(json).to have_key('pagination')
      expect(json).to have_key('meta')

      # Verify only schools within 10km are returned
      school_names = json['schools'].map { |s| s['name'] }
      expect(school_names).to include('Very Close School', 'Nearby School')
      expect(school_names).not_to include('Medium Distance School', 'Far School', 'Very Far School')

      # Verify draft schools are never included
      expect(school_names).not_to include('Draft School')

      # Verify distance calculation is present and reasonable
      very_close = json['schools'].find { |s| s['name'] == 'Very Close School' }
      expect(very_close['distance_km']).to be < 1.0

      nearby = json['schools'].find { |s| s['name'] == 'Nearby School' }
      expect(nearby['distance_km']).to be_between(5.0, 8.0)

      # Verify each school has required fields
      json['schools'].each do |school|
        expect(school).to have_key('id')
        expect(school).to have_key('name')
        expect(school).to have_key('slug')
        expect(school).to have_key('address')
        expect(school).to have_key('distance_km')
        expect(school).to have_key('url')
      end

      # Verify meta information is correct
      expect(json['meta']['radius_km']).to eq 10
      expect(json['meta']['showing_all']).to be false
      expect(json['meta']['home_location']['lat']).to eq 13.7563
      expect(json['meta']['home_location']['lng']).to eq 100.5018
      expect(json['meta']['filtered_count']).to eq 2
    end

    it 'respects different radius values to include/exclude schools at various distances' do
      # Test with 25km radius
      get filtered_schools_path, params: home_location.merge(radius: 25), as: :json

      json = JSON.parse(response.body)
      school_names = json['schools'].map { |s| s['name'] }

      # Should include schools up to ~20km away
      expect(school_names).to include('Very Close School', 'Nearby School', 'Medium Distance School')
      expect(school_names).not_to include('Far School', 'Very Far School')

      # Test with 50km radius
      get filtered_schools_path, params: home_location.merge(radius: 50), as: :json

      json = JSON.parse(response.body)
      school_names = json['schools'].map { |s| s['name'] }

      # Should include schools up to ~40km away
      expect(school_names).to include('Very Close School', 'Nearby School',
                                      'Medium Distance School', 'Far School')
      expect(school_names).not_to include('Very Far School')
    end

    it 'handles show_all parameter to return all schools regardless of distance' do
      get filtered_schools_path, params: home_location.merge(show_all: 'true'), as: :json

      json = JSON.parse(response.body)
      school_names = json['schools'].map { |s| s['name'] }

      # Should include all published schools (up to pagination limit)
      # When showing all, schools are sorted by name alphabetically
      expect(school_names.size).to be > 0
      # But still exclude draft schools
      expect(school_names).not_to include('Draft School')

      # When showing all, distance should be null
      json['schools'].each do |school|
        expect(school['distance_km']).to be_nil
      end

      expect(json['meta']['showing_all']).to be true
    end

    it 'properly paginates results and provides correct pagination metadata' do
      # Create more schools to test pagination - place them close to ensure they're included
      20.times do |i|
        create(:school, name: "Extra School #{i}") do |school|
          # Place them within 1km of home location
          school.place.update!(lat: 13.756 + (i * 0.0001), lng: 100.502)
        end
      end

      # Request first page with small page size - use show_all to ensure consistent results
      # Note: Controller has minimum per_page of 10 based on the filter_params method
      get filtered_schools_path, params: home_location.merge(show_all: 'true', per_page: 10, page: 1), as: :json

      json = JSON.parse(response.body)

      # Should get 10 schools (the minimum per_page value)
      expect(json['schools'].size).to eq 10
      expect(json['pagination']['current_page']).to eq 1
      expect(json['pagination']['per_page']).to eq 10
      expect(json['pagination']['has_next']).to be true
      expect(json['pagination']['has_prev']).to be false

      # Request second page
      get filtered_schools_path, params: home_location.merge(show_all: 'true', per_page: 10, page: 2), as: :json

      json = JSON.parse(response.body)

      expect(json['pagination']['current_page']).to eq 2
      expect(json['pagination']['has_prev']).to be true

      # Request third page to verify pagination continues correctly
      get filtered_schools_path, params: home_location.merge(show_all: 'true', per_page: 10, page: 3), as: :json

      json = JSON.parse(response.body)

      expect(json['pagination']['current_page']).to eq 3
      expect(json['pagination']['has_prev']).to be true
      # Should have some schools on this page (5 base schools + 20 extra = 25 total)
      expect(json['schools'].size).to be > 0
    end

    it 'requires home location coordinates and returns error without them' do
      get filtered_schools_path, as: :json

      expect(response).to have_http_status(:bad_request)

      json = JSON.parse(response.body)
      expect(json['error']).to eq 'Home location required'
    end

    it 'validates and clamps radius parameter within acceptable range' do
      # Test radius too small (should clamp to 1)
      get filtered_schools_path, params: home_location.merge(radius: 0), as: :json
      json = JSON.parse(response.body)
      expect(json['meta']['radius_km']).to eq 1

      # Test radius too large (should clamp to 100)
      get filtered_schools_path, params: home_location.merge(radius: 500), as: :json
      json = JSON.parse(response.body)
      expect(json['meta']['radius_km']).to eq 100
    end

    it 'correctly calculates distances using haversine formula' do
      # Place a school at a known distance
      # Using coordinates that should be approximately 11.1km apart
      create(:school, name: 'Distance Test School') do |school|
        school.place.update!(lat: 13.8563, lng: 100.5018) # Exactly 0.1 degrees north
      end

      get filtered_schools_path, params: home_location.merge(radius: 15), as: :json

      json = JSON.parse(response.body)
      test_result = json['schools'].find { |s| s['name'] == 'Distance Test School' }

      # 0.1 degrees latitude ≈ 11.1km
      expect(test_result['distance_km']).to be_between(11.0, 11.2)
    end

    it 'maintains data integrity by not allowing parameter injection attacks' do
      # Try to inject SQL or manipulate the query
      malicious_params = home_location.merge(
        radius: "50; DROP TABLE schools;--",
        page: "1 OR 1=1",
        per_page: "25 UNION SELECT * FROM users"
      )

      get filtered_schools_path, params: malicious_params, as: :json

      # Should handle gracefully and use defaults for invalid params
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['meta']['radius_km']).to eq 50 # Parsed as integer
      expect(json['pagination']['current_page']).to eq 1
    end

    context 'with invalid coordinates' do
      it 'handles invalid latitude gracefully' do
        get filtered_schools_path, params: { home_lat: 'invalid', home_lng: 100.5018 }, as: :json
        expect(response).to have_http_status(:bad_request)
      end

      it 'handles invalid longitude gracefully' do
        get filtered_schools_path, params: { home_lat: 13.7563, home_lng: 'invalid' }, as: :json
        expect(response).to have_http_status(:bad_request)
      end

      it 'rejects coordinates outside valid ranges' do
        # Latitude out of range
        get filtered_schools_path, params: { home_lat: 91, home_lng: 100.5018 }, as: :json
        expect(response).to have_http_status(:bad_request)

        # Longitude out of range
        get filtered_schools_path, params: { home_lat: 13.7563, home_lng: 181 }, as: :json
        expect(response).to have_http_status(:bad_request)
      end
    end

    it 'returns consistent results when called multiple times with same parameters' do
      # First request
      get filtered_schools_path, params: home_location.merge(radius: 20), as: :json
      first_response = JSON.parse(response.body)

      # Second identical request
      get filtered_schools_path, params: home_location.merge(radius: 20), as: :json
      second_response = JSON.parse(response.body)

      # Results should be identical
      expect(first_response['schools'].map { |s| s['id'] }).to eq(
        second_response['schools'].map { |s| s['id'] }
      )
      expect(first_response['meta']).to eq(second_response['meta'])
    end
  end
end
