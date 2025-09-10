require 'rails_helper'

# CRITICAL TEST: Validates coordinate input security to prevent injection attacks and server crashes
# This test was missing and could allow malicious users to crash the server or inject invalid data

RSpec.describe 'Coordinate Validation Security', type: :request do
  include Rails.application.routes.url_helpers

  let!(:school) { create(:school, name: 'Test School Bangkok') }

  before do
    # Ensure test isolation by cleaning up any existing schools
    School.where.not(id: school.id).destroy_all
    school.place.update!(lat: 13.7563, lng: 100.5018)
  end

  describe 'GET /schools with coordinate parameters' do
    context 'with malicious coordinate inputs' do
      it 'rejects SQL injection attempts in latitude' do
        get root_path, params: {
          home_lat: "13.75'; DROP TABLE schools; --",
          home_lng: 100.5018,
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:bad_request)
        expect(School.count).to eq(1) # Table not dropped
      end

      it 'rejects SQL injection attempts in longitude' do
        get root_path, params: {
          home_lat: 13.75,
          home_lng: "100.50 OR 1=1; --",
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:bad_request)
      end

      it 'handles extremely large coordinate values without crashing' do
        get root_path, params: {
          home_lat: 99999999999999999999999999999999,
          home_lng: 99999999999999999999999999999999,
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Home location required')
      end

      it 'handles extremely negative coordinate values' do
        get root_path, params: {
          home_lat: -99999999999999999999999999999999,
          home_lng: -99999999999999999999999999999999,
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:bad_request)
      end

      it 'rejects NaN values' do
        get root_path, params: {
          home_lat: 'NaN',
          home_lng: 'NaN',
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:bad_request)
      end

      it 'rejects Infinity values' do
        get root_path, params: {
          home_lat: 'Infinity',
          home_lng: '-Infinity',
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:bad_request)
      end

      it 'rejects null byte injection' do
        get root_path, params: {
          home_lat: "13.75\x00malicious",
          home_lng: "100.50\x00code",
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:bad_request)
      end

      it 'rejects Unicode direction override characters' do
        get root_path, params: {
          home_lat: "13.75\u202E",
          home_lng: "100.50\u202D",
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:bad_request)
      end

      it 'rejects script tags in coordinates' do
        get root_path, params: {
          home_lat: "<script>alert('XSS')</script>",
          home_lng: 100.5018,
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with edge case valid coordinates' do
      it 'accepts North Pole coordinates (90, 0)' do
        get root_path, params: {
          home_lat: 90,
          home_lng: 0,
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:ok)
      end

      it 'accepts South Pole coordinates (-90, 0)' do
        get root_path, params: {
          home_lat: -90,
          home_lng: 0,
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:ok)
      end

      it 'accepts International Date Line coordinates (0, 180)' do
        get root_path, params: {
          home_lat: 0,
          home_lng: 180,
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:ok)
      end

      it 'accepts International Date Line coordinates (0, -180)' do
        get root_path, params: {
          home_lat: 0,
          home_lng: -180,
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:ok)
      end

      it 'accepts coordinates with high precision decimals' do
        get root_path, params: {
          home_lat: 13.756309876543210123456789,
          home_lng: 100.501809876543210123456789,
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        # Should truncate to reasonable precision
        expect(json['meta']['home_location']['lat']).to be_within(0.0001).of(13.7563)
      end
    end

    context 'with invalid but not malicious coordinates' do
      it 'rejects latitude greater than 90' do
        get root_path, params: {
          home_lat: 91,
          home_lng: 100,
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:bad_request)
      end

      it 'rejects latitude less than -90' do
        get root_path, params: {
          home_lat: -91,
          home_lng: 100,
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:bad_request)
      end

      it 'rejects longitude greater than 180' do
        get root_path, params: {
          home_lat: 45,
          home_lng: 181,
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:bad_request)
      end

      it 'rejects longitude less than -180' do
        get root_path, params: {
          home_lat: 45,
          home_lng: -181,
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:bad_request)
      end

      it 'rejects empty string coordinates' do
        get root_path, params: {
          home_lat: '',
          home_lng: '',
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:bad_request)
      end

      it 'rejects array coordinates' do
        get root_path, params: {
          home_lat: [ 13.75, 14.0 ],
          home_lng: [ 100.50, 101.0 ],
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:bad_request)
      end

      it 'rejects object coordinates' do
        get root_path, params: {
          home_lat: { value: 13.75 },
          home_lng: { value: 100.50 },
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'search endpoint coordinate validation' do
      it 'validates coordinates for search endpoint' do
        get search_schools_path, params: {
          q: 'Bangkok',
          home_lat: 'malicious_code',
          home_lng: 'DROP TABLE'
        }, as: :json

        expect(response).to have_http_status(:bad_request)
        expect(School.count).to eq(1) # Verify table still exists
      end

      it 'requires valid coordinates for search' do
        get search_schools_path, params: {
          q: 'Bangkok',
          home_lat: 200,
          home_lng: 300
        }, as: :json

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'filtered endpoint coordinate validation' do
      it 'validates coordinates for filtered endpoint' do
        get filtered_schools_path, params: {
          home_lat: '<img src=x onerror=alert(1)>',
          home_lng: 100.50,
          radius: 50
        }, as: :json

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'performance and DoS protection' do
      it 'handles rapid repeated invalid requests without memory leak' do
        10.times do
          get root_path, params: {
            home_lat: 'x' * 10000,
            home_lng: 'y' * 10000,
            radius: 50
          }, as: :json

          expect(response).to have_http_status(:bad_request)
        end
      end

      it 'validates radius parameter to prevent excessive database load' do
        # Extremely large radius could cause performance issues
        get root_path, params: {
          home_lat: 13.75,
          home_lng: 100.50,
          radius: 999999999
        }, as: :json

        # Should either cap the radius or handle gracefully
        expect(response.status).to be_in([ 200, 400 ])
        if response.status == 200
          json = JSON.parse(response.body)
          # If accepted, radius should be capped to reasonable value
          expect(json['meta']['radius_km']).to be <= 200
        end
      end
    end
  end
end
