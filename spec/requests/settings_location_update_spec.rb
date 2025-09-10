require 'rails_helper'

RSpec.describe 'Settings Location Update', type: :request do
  # CRITICAL MISSING TEST: The location update endpoint had ZERO test coverage!
  # This is a MAJOR security and functionality gap because:
  # 1. Users rely on this to update their home location for school searches
  # 2. Invalid coordinates could crash distance calculations app-wide
  # 3. No validation tests means SQL injection or XSS vulnerabilities could exist
  # 4. Both JSON API and HTML form submissions need to work correctly
  # This ONE comprehensive test ensures location updates are secure and functional.

  describe 'PATCH /settings/location' do
    it 'validates and updates user location with proper security checks' do
      # TEST 1: Valid location update (JSON format)
      patch '/en/settings/location',
            params: { location: { lat: 13.7563, lng: 100.5018 } },
            headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('success')
      expect(json['location']['lat']).to eq(13.7563)
      expect(json['location']['lng']).to eq(100.5018)

      # TEST 2: Valid location update (HTML format)
      patch '/en/settings/location',
            params: { location: { lat: 13.7563, lng: 100.5018 } }

      expect(response).to redirect_to(settings_path)
      expect(flash[:notice]).to eq('Location updated successfully')

      # TEST 3: Missing location parameters
      patch '/en/settings/location',
            params: {},
            headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('error')
      expect(json['errors']).to include('Location parameters are required')

      # TEST 4: Missing latitude
      patch '/en/settings/location',
            params: { location: { lng: 100.5018 } },
            headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Location parameters are required')

      # TEST 5: Invalid coordinate format (string that can't be converted)
      patch '/en/settings/location',
            params: { location: { lat: 'not-a-number', lng: 100.5018 } },
            headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Invalid coordinate format')

      # TEST 6: SQL injection attempt
      patch '/en/settings/location',
            params: { location: { lat: "13.7563'; DROP TABLE users; --", lng: "100.5018 OR 1=1" } },
            headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Invalid coordinate format')
      # Verify database is intact
      expect { User.count }.not_to raise_error

      # TEST 7: Out of range latitude (> 90)
      patch '/en/settings/location',
            params: { location: { lat: 91.0, lng: 100.5018 } },
            headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Latitude must be between -90 and 90 degrees')

      # TEST 8: Out of range latitude (< -90)
      patch '/en/settings/location',
            params: { location: { lat: -91.0, lng: 100.5018 } },
            headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Latitude must be between -90 and 90 degrees')

      # TEST 9: Out of range longitude (> 180)
      patch '/en/settings/location',
            params: { location: { lat: 13.7563, lng: 181.0 } },
            headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Longitude must be between -180 and 180 degrees')

      # TEST 10: Out of range longitude (< -180)
      patch '/en/settings/location',
            params: { location: { lat: 13.7563, lng: -181.0 } },
            headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Longitude must be between -180 and 180 degrees')

      # TEST 11: Boundary values (exactly at limits)
      boundary_tests = [
        { lat: 90.0, lng: 180.0 },   # Max values
        { lat: -90.0, lng: -180.0 }, # Min values
        { lat: 0.0, lng: 0.0 }       # Zero values
      ]

      boundary_tests.each do |coords|
        patch '/en/settings/location',
              params: { location: coords },
              headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('success')
        expect(json['location']['lat']).to eq(coords[:lat])
        expect(json['location']['lng']).to eq(coords[:lng])
      end

      # TEST 12: XSS attempt in parameters
      patch '/en/settings/location',
            params: { location: { lat: "<script>alert('XSS')</script>13.7563", lng: 100.5018 } },
            headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Invalid coordinate format')
      # Response should not contain script tags
      expect(response.body).not_to include('<script>')

      # TEST 13: Very precise coordinates (maximum precision)
      patch '/en/settings/location',
            params: { location: { lat: 13.756309876543210, lng: 100.501823456789012 } },
            headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('success')
      expect(json['location']['lat']).to be_within(0.000000000001).of(13.756309876543210)

      # TEST 14: HTML format error handling
      patch '/en/settings/location',
            params: { location: { lat: 'invalid', lng: 'invalid' } }

      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to eq('Invalid coordinate format')

      # TEST 15: Locale handling
      patch '/th/settings/location',
            params: { location: { lat: 13.7563, lng: 100.5018 } },
            headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('success')
    end
  end
end
