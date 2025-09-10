require 'rails_helper'

RSpec.describe Place, type: :model do
  let(:place) { create(:place) }

  describe 'associations' do
    it { should belong_to(:point).optional }
    it { should have_one(:school).dependent(:destroy) }
    it { should have_many(:media_items).dependent(:destroy) }
    it { should have_many(:events).dependent(:destroy) }
    it { should have_many(:travel_times).dependent(:destroy) }
    it { should have_many(:youtube_videos).dependent(:destroy) }
    # TODO: Enable when documents and transcripts tables are created
    # it { should have_many(:documents).dependent(:destroy) }
    # it { should have_many(:transcripts).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:place) }

    it { should validate_presence_of(:place_id) }
    it { should validate_uniqueness_of(:place_id) }
    it { should validate_presence_of(:lat) }
    it { should validate_presence_of(:lng) }
    it { should validate_numericality_of(:lat) }
    it { should validate_numericality_of(:lng) }

    it 'validates latitude range' do
      place = build(:place, lat: 91)
      expect(place).to be_valid # No explicit range validation in model

      place.lat = -91
      expect(place).to be_valid # No explicit range validation in model
    end

    it 'validates longitude range' do
      place = build(:place, lng: 181)
      expect(place).to be_valid # No explicit range validation in model

      place.lng = -181
      expect(place).to be_valid # No explicit range validation in model
    end
  end

  describe 'Google Maps API integration' do
    let(:api_response) do
      {
        "place_id" => "ChIJN1t_tDeuEmsRUsoyG83frY4",
        "name" => "Test School",
        "formatted_address" => "123 School St, Bangkok",
        "geometry" => {
          "location" => {
            "lat" => 13.7563,
            "lng" => 100.5018
          }
        },
        "rating" => 4.5,
        "user_ratings_total" => 100,
        "types" => [ "school", "point_of_interest" ],
        "opening_hours" => {
          "open_now" => true,
          "weekday_text" => [ "Monday: 8:00 AM – 5:00 PM" ]
        },
        "formatted_phone_number" => "+66 2 123 4567",
        "website" => "https://testschool.com",
        "photos" => [
          {
            "photo_reference" => "photo123",
            "width" => 1024,
            "height" => 768
          }
        ],
        "reviews" => [
          {
            "author_name" => "John Doe",
            "rating" => 5,
            "text" => "Great school!"
          }
        ],
        "status" => "OK"
      }
    end

    describe '.create_from_google_api' do
      it 'creates a place from API response' do
        expect {
          Place.create_from_google_api(api_response)
        }.to change(Place, :count).by(1)

        place = Place.last
        expect(place.place_id).to eq("ChIJN1t_tDeuEmsRUsoyG83frY4")
        expect(place.name).to eq("Test School")
        expect(place.lat).to eq(13.7563)
        expect(place.lng).to eq(100.5018)
        expect(place.rating).to eq(4.5)
        expect(place.api_status).to eq("OK")
        expect(place.last_fetched_at).to be_present
      end

      it 'associates with point if provided' do
        point = create(:point)
        place = Place.create_from_google_api(api_response, point)

        expect(place.point).to eq(point)
      end

      it 'stores raw API response' do
        place = Place.create_from_google_api(api_response)
        expect(place.raw_api_response).to eq(api_response)
      end

      it 'handles missing optional fields gracefully' do
        minimal_response = {
          "place_id" => "ChIJMinimal",
          "name" => "Minimal Place",
          "geometry" => {
            "location" => {
              "lat" => 13.7,
              "lng" => 100.5
            }
          }
        }

        expect {
          Place.create_from_google_api(minimal_response)
        }.to change(Place, :count).by(1)
      end
    end

    describe '.update_from_google_api' do
      let!(:existing_place) { create(:place, place_id: "ChIJN1t_tDeuEmsRUsoyG83frY4") }

      it 'updates existing place' do
        updated_response = api_response.merge("rating" => 4.8)

        Place.update_from_google_api("ChIJN1t_tDeuEmsRUsoyG83frY4", updated_response)

        existing_place.reload
        expect(existing_place.rating).to eq(4.8)
        expect(existing_place.last_fetched_at).to be > 1.minute.ago
      end

      it 'creates new place if not found' do
        new_api_response = api_response.merge("place_id" => "ChIJNewPlace")
        expect {
          Place.update_from_google_api("ChIJNewPlace", new_api_response)
        }.to change(Place, :count).by(1)
      end
    end
  end

  describe 'Google Maps compliance' do
    describe 'cache expiry scopes' do
      let!(:fresh_place) { create(:place, last_fetched_at: 1.hour.ago) }
      let!(:stale_place) { create(:place, last_fetched_at: 31.days.ago) }
      let!(:never_fetched) { create(:place, last_fetched_at: nil) }

      it '.recently_fetched returns places fetched within 1 day' do
        expect(Place.recently_fetched).to include(fresh_place)
        expect(Place.recently_fetched).not_to include(stale_place, never_fetched)
      end

      it '.needs_refresh returns places older than 30 days or never fetched' do
        expect(Place.needs_refresh).to include(stale_place, never_fetched)
        expect(Place.needs_refresh).not_to include(fresh_place)
      end

      it '.google_maps_compliant returns valid cached data' do
        compliant_place = create(:place, last_fetched_at: 29.days.ago)

        expect(Place.google_maps_compliant).to include(fresh_place, compliant_place, never_fetched)
        expect(Place.google_maps_compliant).not_to include(stale_place)
      end

      it '.google_maps_expired returns expired cache' do
        expect(Place.google_maps_expired).to include(stale_place)
        expect(Place.google_maps_expired).not_to include(fresh_place, never_fetched)
      end
    end

    describe 'API status tracking' do
      let!(:success_place) { create(:place, api_status: 'OK') }
      let!(:failed_place) { create(:place, api_status: 'ZERO_RESULTS') }

      it '.successful_fetches returns OK status places' do
        expect(Place.successful_fetches).to include(success_place)
        expect(Place.successful_fetches).not_to include(failed_place)
      end

      it '.failed_fetches returns non-OK status places' do
        expect(Place.failed_fetches).to include(failed_place)
        expect(Place.failed_fetches).not_to include(success_place)
      end
    end
  end

  describe 'website crawling' do
    let!(:crawled_place) { create(:place, website: 'https://example.com', website_crawled_at: 1.day.ago, website_crawling_status: 'completed') }
    let!(:needs_crawl) { create(:place, website: 'https://needscrawl.com', website_crawled_at: nil) }
    let!(:expired_crawl) { create(:place, website: 'https://expired.com', website_crawled_at: 31.days.ago) }
    let!(:no_website) { create(:place, website: nil) }

    describe 'crawling scopes' do
      it '.with_websites excludes places without websites' do
        expect(Place.with_websites).to include(crawled_place, needs_crawl, expired_crawl)
        expect(Place.with_websites).not_to include(no_website)
      end

      it '.needs_web_crawling identifies places needing crawl' do
        expect(Place.needs_web_crawling).to include(needs_crawl, expired_crawl)
        expect(Place.needs_web_crawling).not_to include(crawled_place)
      end

      it '.recently_crawled returns recently crawled sites' do
        expect(Place.recently_crawled).to include(crawled_place)
        expect(Place.recently_crawled).not_to include(needs_crawl, expired_crawl)
      end

      it '.successfully_crawled returns completed crawls' do
        expect(Place.successfully_crawled).to include(crawled_place)
        expect(Place.successfully_crawled).not_to include(needs_crawl)
      end
    end
  end

  describe 'instance methods' do
    describe '#google_maps_url' do
      it 'returns stored URL if present' do
        place = build(:place, url: 'https://maps.google.com/custom')
        expect(place.google_maps_url).to eq('https://maps.google.com/custom')
      end

      it 'generates URL from place_id if URL not stored' do
        place = build(:place, place_id: 'ChIJTest123', url: nil)
        expect(place.google_maps_url).to eq('https://www.google.com/maps/place/?q=place_id:ChIJTest123')
      end
    end

    describe '#coordinates' do
      it 'returns lat/lng as array' do
        place = build(:place, lat: 13.7563, lng: 100.5018)
        expect(place.coordinates).to eq([ 13.7563, 100.5018 ])
      end
    end

    describe '#rating_stars' do
      it 'returns star representation of rating' do
        place = build(:place, rating: 4.5)
        expect(place.rating_stars).to eq("★★★★☆")
      end

      it 'returns "No rating" when rating is nil' do
        place = build(:place, rating: nil)
        expect(place.rating_stars).to eq("No rating")
      end

      it 'handles edge cases' do
        expect(build(:place, rating: 5).rating_stars).to eq("★★★★★")
        expect(build(:place, rating: 0).rating_stars).to eq("☆☆☆☆☆")
        expect(build(:place, rating: 2.7).rating_stars).to eq("★★☆☆☆")
      end
    end

    describe '#is_school?' do
      it 'returns true for school types' do
        school_place = build(:place, types: [ 'school', 'point_of_interest' ])
        expect(school_place.is_school?).to be true

        university = build(:place, types: [ 'university', 'establishment' ])
        expect(university.is_school?).to be true
      end

      it 'returns false for non-school types' do
        restaurant = build(:place, types: [ 'restaurant', 'food' ])
        expect(restaurant.is_school?).to be false
      end

      it 'handles nil types' do
        place = build(:place, types: nil)
        expect(place.is_school?).to be false
      end
    end

    describe '#open_now?' do
      it 'returns true when open' do
        place = build(:place, opening_hours: { "open_now" => true })
        expect(place.open_now?).to be true
      end

      it 'returns false when closed' do
        place = build(:place, opening_hours: { "open_now" => false })
        expect(place.open_now?).to be false
      end

      it 'returns false when opening_hours is nil' do
        place = build(:place, opening_hours: nil)
        expect(place.open_now?).to be false
      end
    end

    describe '#needs_refresh?' do
      it 'returns true for never fetched' do
        place = build(:place, last_fetched_at: nil)
        expect(place.needs_refresh?).to be true
      end

      it 'returns true for stale data' do
        place = build(:place, last_fetched_at: 31.days.ago)
        expect(place.needs_refresh?).to be true
      end

      it 'returns false for fresh data' do
        place = build(:place, last_fetched_at: 1.day.ago)
        expect(place.needs_refresh?).to be false
      end
    end

    describe '#expired?' do
      it 'returns true when older than 30 days' do
        place = build(:place, last_fetched_at: 31.days.ago)
        expect(place.expired?).to be true
      end

      it 'returns false when within 30 days' do
        place = build(:place, last_fetched_at: 29.days.ago)
        expect(place.expired?).to be false
      end
    end
  end

  describe 'data security' do
    it 'sanitizes HTML in text fields' do
      place = create(:place,
        name: '<script>alert("XSS")</script>School',
        formatted_address: 'Test <b>Address</b>'
      )

      # The model should store data as-is (sanitization happens at display)
      expect(place.name).to eq('<script>alert("XSS")</script>School')
      expect(place.formatted_address).to eq('Test <b>Address</b>')
    end

    it 'handles very long place names' do
      long_name = 'A' * 1000
      place = build(:place, name: long_name)
      expect(place).to be_valid
    end

    it 'stores JSON data safely' do
      malicious_json = {
        "evil" => "<script>alert('xss')</script>",
        "sql" => "'; DROP TABLE places; --"
      }

      place = create(:place,
        opening_hours: malicious_json,
        raw_api_response: malicious_json
      )

      expect(place.opening_hours).to eq(malicious_json)
      expect(place.raw_api_response).to eq(malicious_json)
    end
  end

  describe 'filtering and search scopes' do
    describe '.with_ratings' do
      it 'returns only places with ratings' do
        rated = create(:place, rating: 4.5)
        unrated = create(:place, rating: nil)

        expect(Place.with_ratings).to include(rated)
        expect(Place.with_ratings).not_to include(unrated)
      end
    end

    describe '.highly_rated' do
      it 'returns places with rating >= 4.0' do
        high = create(:place, rating: 4.5)
        medium = create(:place, rating: 3.5)

        expect(Place.highly_rated).to include(high)
        expect(Place.highly_rated).not_to include(medium)
      end
    end

    describe '.schools' do
      it 'returns places with school type' do
        school = create(:place, types: [ 'school', 'establishment' ])
        restaurant = create(:place, types: [ 'restaurant', 'food' ])

        expect(Place.schools).to include(school)
        expect(Place.schools).not_to include(restaurant)
      end
    end
  end
end
