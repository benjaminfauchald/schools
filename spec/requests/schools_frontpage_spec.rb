require 'rails_helper'

RSpec.describe 'Schools Frontpage', type: :request do
  let!(:school1) { create(:school, name: 'Bangkok International School') }
  let!(:school2) { create(:school, name: 'Local Thai School') }

  before do
    # Set up schools at different locations
    school1.place.update!(lat: 13.692000, lng: 100.537100)
    school2.place.update!(lat: 13.700000, lng: 100.540000)
  end

  describe 'GET /' do
    context 'without location parameters' do
      it 'redirects to onboarding' do
        get root_path
        expect(response).to redirect_to('/onboarding')
      end

      it 'renders onboarding page after redirect' do
        get root_path
        expect(response).to redirect_to('/onboarding')
        follow_redirect!
        expect(response).to have_http_status(:success)
      end
    end

    context 'with location parameters' do
      let(:valid_params) do
        {
          home_lat: 13.691987076564292,
          home_lng: 100.53707963009823,
          radius: 50
        }
      end

      it 'returns successful response with location' do
        get root_path, params: valid_params
        expect(response).to have_http_status(:success)
      end

      it 'handles radius parameter' do
        get root_path, params: valid_params.merge(radius: 10)
        expect(response).to have_http_status(:success)
      end

      it 'handles show_all parameter' do
        get root_path, params: valid_params.merge(show_all: true)
        expect(response).to have_http_status(:success)
      end

      it 'handles pagination parameters' do
        get root_path, params: valid_params.merge(page: 1, per_page: 10)
        expect(response).to have_http_status(:success)
      end
    end

    context 'JSON responses' do
      let(:json_params) do
        {
          home_lat: 13.691987,
          home_lng: 100.537079,
          radius: 25
        }
      end

      it 'returns JSON response when requested' do
        get root_path, params: json_params, headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('application/json')

        json = JSON.parse(response.body)
        expect(json).to have_key('schools')
        expect(json).to have_key('pagination')
        expect(json).to have_key('meta')
      end

      it 'returns error for JSON requests without location' do
        get root_path, headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['error']).to include('location')
      end
    end
  end

  describe 'GET /schools/filtered' do
    let(:filter_params) do
      {
        home_lat: 13.691987,
        home_lng: 100.537079,
        radius: 20
      }
    end

    it 'returns filtered schools as JSON' do
      get filtered_schools_path, params: filter_params

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to have_key('schools')
      expect(json).to have_key('meta')
    end

    it 'requires location parameters' do
      get filtered_schools_path

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json['error']).to include('location')
    end
  end

  describe 'frontpage search functionality' do
    let(:frontpage_params) do
      {
        radius: 50,
        show_all: false,
        page: 1,
        home_lat: 13.691987076564292,
        home_lng: 100.53707963009823
      }
    end

    it 'handles search query in frontpage URL without errors' do
      # Test the exact URL pattern from the screenshot: search for "sch"
      get root_path, params: frontpage_params.merge(search: 'sch')

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Schools')
    end

    it 'handles search query with partial school names' do
      # Test searching for "School" which should match both test schools
      get root_path, params: frontpage_params.merge(search: 'School')

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Schools')
    end

    it 'handles search query with specific school name' do
      # Test searching for "International" which should match Bangkok International School
      get root_path, params: frontpage_params.merge(search: 'International')

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Schools')
    end

    it 'handles empty search query gracefully' do
      # Test with empty search - should not crash
      get root_path, params: frontpage_params.merge(search: '')

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Schools')
    end

    it 'handles search with no matching results gracefully' do
      # Test search that won't match anything
      get root_path, params: frontpage_params.merge(search: 'nonexistent-xyz-school-name')

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Schools')
    end
  end

  describe 'GET /schools/search' do
    let(:search_params) do
      {
        q: 'International',
        home_lat: 13.691987,
        home_lng: 100.537079
      }
    end

    it 'returns search results with distance' do
      get search_schools_path, params: search_params, headers: { 'Accept' => 'application/json' }

      # With location params but possibly no session, should return JSON
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to have_key('schools')
    end

    it 'returns empty results for empty query' do
      get search_schools_path, params: { q: '', home_lat: 13.691987, home_lng: 100.537079 }, headers: { 'Accept' => 'application/json' }

      # Empty query returns empty results
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['schools']).to be_empty
    end

    it 'requires location for search' do
      get search_schools_path, params: { q: 'School' }

      # Without location, redirects to root_path for HTML
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'parameter validation' do
    it 'handles extreme parameter values gracefully' do
      get root_path, params: {
        home_lat: 13.691987,
        home_lng: 100.537079,
        radius: 1000,     # Very large
        page: -1,         # Negative
        per_page: 500     # Too large
      }

      expect(response).to have_http_status(:success)
    end

    it 'handles invalid coordinates' do
      get root_path, params: {
        home_lat: 200,    # Invalid latitude
        home_lng: 500     # Invalid longitude
      }

      # Invalid coordinates should redirect to onboarding
      expect(response).to redirect_to('/onboarding')
    end
  end

  describe 'puppeteer detection' do
    it 'handles headless browser requests' do
      get root_path, headers: { 'User-Agent' => 'HeadlessChrome/91.0.4472.77' }

      expect(response).to have_http_status(:success)
    end
  end
end
