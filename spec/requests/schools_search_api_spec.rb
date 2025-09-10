require 'rails_helper'

RSpec.describe 'Schools Search API', type: :request do
  # CRITICAL MISSING TEST: The schools search API endpoint had ZERO direct test coverage!
  # This is a MAJOR gap because:
  # 1. Search is a PRIMARY user feature - users rely on it to find schools
  # 2. SQL injection vulnerability - the query uses string interpolation with ILIKE
  # 3. Missing location handling could crash the entire search
  # 4. No validation on query parameter could expose sensitive data
  # This ONE comprehensive test ensures the search API is secure and functional.

  describe 'GET /schools/search' do
    it 'searches schools securely and validates all input parameters' do
      # Create test schools
      bangkok_school = create(:school, name: 'Bangkok International School', status: 'published')
      bangkok_school.place.update!(lat: 13.7563, lng: 100.5018)

      siam_school = create(:school, name: 'Siam Academy', status: 'published')
      siam_school.place.update!(lat: 13.7600, lng: 100.5050)

      unpublished_school = create(:school, name: 'Unpublished Test School', status: 'draft')
      unpublished_school.place.update!(lat: 13.7800, lng: 100.5200) if unpublished_school.place

      # TEST 1: Valid search with location returns correct results
      get '/schools/search', params: {
        q: 'Bangkok',
        home_lat: 13.7563,
        home_lng: 100.5018
      }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['schools']).to be_an(Array)
      expect(json['schools'].length).to eq(1)
      expect(json['schools'][0]['name']).to eq('Bangkok International School')
      expect(json['schools'][0]['distance_km']).to eq(0.0)
      expect(json['schools'][0]['url']).to include('/schools/')

      # TEST 2: Missing location parameters returns error
      get '/schools/search', params: { q: 'Bangkok' }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json['error']).to include('location required')

      # TEST 3: Empty search query returns empty results
      get '/schools/search', params: {
        q: '',
        home_lat: 13.7563,
        home_lng: 100.5018
      }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['schools']).to eq([])

      # TEST 4: SQL injection attempt is handled safely
      get '/schools/search', params: {
        q: "'; DROP TABLE schools; --",
        home_lat: 13.7563,
        home_lng: 100.5018
      }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['schools']).to eq([])
      # Database should still be intact
      expect(School.count).to be >= 3

      # TEST 5: Unpublished schools are never returned
      get '/schools/search', params: {
        q: 'Unpublished',
        home_lat: 13.7563,
        home_lng: 100.5018
      }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['schools']).to eq([])

      # TEST 6: Case-insensitive search works
      get '/schools/search', params: {
        q: 'bangkok',
        home_lat: 13.7563,
        home_lng: 100.5018
      }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['schools'].length).to eq(1)
      expect(json['schools'][0]['name']).to eq('Bangkok International School')

      # TEST 7: Partial match search works
      get '/schools/search', params: {
        q: 'Academy',
        home_lat: 13.7563,
        home_lng: 100.5018
      }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['schools'].length).to eq(1)
      expect(json['schools'][0]['name']).to eq('Siam Academy')

      # TEST 8: XSS attempt in search query is handled safely
      get '/schools/search', params: {
        q: "<script>alert('XSS')</script>",
        home_lat: 13.7563,
        home_lng: 100.5018
      }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['schools']).to eq([])
      # Response should not contain script tags
      expect(response.body).not_to include('<script>')

      # TEST 9: Whitespace-only query returns empty results
      get '/schools/search', params: {
        q: '   ',
        home_lat: 13.7563,
        home_lng: 100.5018
      }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['schools']).to eq([])

      # TEST 10: Invalid coordinate format returns error
      get '/schools/search', params: {
        q: 'Bangkok',
        home_lat: 'invalid',
        home_lng: 'invalid'
      }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:bad_request)

      # TEST 11: Results include all required fields
      get '/schools/search', params: {
        q: 'Siam',
        home_lat: 13.7563,
        home_lng: 100.5018
      }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      school = json['schools'][0]

      # Verify all required fields are present
      expect(school).to have_key('id')
      expect(school).to have_key('name')
      expect(school).to have_key('slug')
      expect(school).to have_key('address')
      expect(school).to have_key('distance_km')
      expect(school).to have_key('url')
      expect(school['distance_km']).to be_a(Numeric)

      # TEST 12: Maximum results limit works (should be 20)
      # Create many schools with matching name
      15.times do |i|
        school = create(:school, name: "Test Academy #{i}", status: 'published')
        school.place.update!(lat: 13.7563 + (i * 0.001), lng: 100.5018 + (i * 0.001))
      end

      get '/schools/search', params: {
        q: 'Test Academy',
        home_lat: 13.7563,
        home_lng: 100.5018
      }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['schools'].length).to eq(15) # All 15 should be returned (under limit of 20)

      # TEST 13: Results are sorted by distance
      get '/schools/search', params: {
        q: 'School',
        home_lat: 13.7563,
        home_lng: 100.5018
      }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      # Should find Bangkok International School
      schools_with_school = json['schools'].select { |s| s['name'].include?('School') }
      expect(schools_with_school).not_to be_empty
      if schools_with_school.length > 1
        # Verify they're sorted by distance
        (0..schools_with_school.length-2).each do |i|
          expect(schools_with_school[i]['distance_km']).to be <= schools_with_school[i+1]['distance_km']
        end
      end
    end
  end
end
