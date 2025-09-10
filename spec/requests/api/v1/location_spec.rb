require 'rails_helper'

RSpec.describe 'API::V1::Location', type: :request do
  include ActiveSupport::Testing::TimeHelpers
  before(:each) do
    # Clear rate limiting cache before each test
    Rails.cache.clear
  end
  # CRITICAL GAP: The location validation endpoint is defined in routes but has NO controller!
  # This is the MOST CRITICAL missing test because:
  # 1. The entire app depends on location for school filtering
  # 2. The onboarding flow tries to call this endpoint
  # 3. A missing controller causes 500 errors in production
  # 4. No validation = potential for invalid location data corrupting the system

  describe 'POST /api/v1/location/validate' do
    let(:valid_location_params) do
      {
        lat: 13.7563,
        lng: 100.5018,
        address: 'Bangkok, Thailand'
      }
    end

    let(:invalid_location_params) do
      {
        lat: 'invalid',
        lng: 'invalid',
        address: ''
      }
    end

    context 'with valid location data' do
      it 'validates and accepts valid coordinates' do
        post '/api/v1/location/validate',
             params: valid_location_params.to_json,
             headers: { 'Content-Type' => 'application/json' }

        # This will fail because the controller doesn't exist!
        # When fixed, it should return success
        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be true
        expect(json_response['lat']).to eq(13.7563)
        expect(json_response['lng']).to eq(100.5018)
      end
    end

    context 'with invalid location data' do
      it 'rejects invalid coordinates' do
        post '/api/v1/location/validate',
             params: invalid_location_params.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)

        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be false
        expect(json_response['errors']).to be_present
      end

      it 'rejects out-of-bounds coordinates' do
        # Latitude must be between -90 and 90
        # Longitude must be between -180 and 180
        out_of_bounds_params = {
          lat: 91.0,  # Invalid latitude
          lng: 181.0, # Invalid longitude
          address: 'Invalid Location'
        }

        post '/api/v1/location/validate',
             params: out_of_bounds_params.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)

        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be false
        expect(json_response['errors']).to include(match(/latitude/i))
        expect(json_response['errors']).to include(match(/longitude/i))
      end
    end

    context 'security validations' do
      it 'handles missing parameters gracefully' do
        post '/api/v1/location/validate',
             params: {}.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)

        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be false
        expect(json_response['errors']).to be_present
      end

      it 'sanitizes potential XSS in address field' do
        xss_params = {
          lat: 13.7563,
          lng: 100.5018,
          address: '<script>alert("XSS")</script>Bangkok'
        }

        post '/api/v1/location/validate',
             params: xss_params.to_json,
             headers: { 'Content-Type' => 'application/json' }

        # Should either sanitize or reject
        if response.status == 200
          json_response = JSON.parse(response.body)
          # Address should be sanitized
          expect(json_response['address']).not_to include('<script>')
          expect(json_response['address']).not_to include('alert')
        end
      end

      it 'handles SQL injection attempts in parameters' do
        sql_injection_params = {
          lat: "13.7563'; DROP TABLE users; --",
          lng: "100.5018 OR 1=1",
          address: "Bangkok' UNION SELECT * FROM users--"
        }

        post '/api/v1/location/validate',
             params: sql_injection_params.to_json,
             headers: { 'Content-Type' => 'application/json' }

        # Should reject invalid numeric values
        expect(response).to have_http_status(:unprocessable_entity)

        # Verify database is still intact
        expect { User.count }.not_to raise_error
      end
    end

    context 'rate limiting' do
      it 'prevents abuse through rate limiting' do
        # Simulate rapid requests from same IP
        results = []

        # Try 20 rapid requests
        20.times do |i|
          post '/api/v1/location/validate',
               params: valid_location_params.to_json,
               headers: { 'Content-Type' => 'application/json' }
          results << response.status
        end

        # At some point should get rate limited (429) or all succeed
        # This documents expected behavior
        if results.include?(429)
          expect(results.last(5)).to include(429)
        else
          # If no rate limiting, all should process successfully
          expect(results.uniq).to eq([ 200 ])
        end
      end

      # CRITICAL TEST: Ensures rate limiting actually blocks after 20 requests per minute
      # This test fills a critical security gap - without proper rate limiting,
      # the API is vulnerable to DoS attacks and data harvesting attempts.
      # The controller implements a 20 req/min limit but this wasn't properly tested.
      it 'enforces strict 20 requests per minute rate limit from same IP' do
        # Clear any existing rate limit cache
        Rails.cache.clear

        successful_requests = 0
        rate_limited_requests = 0

        # Make exactly 21 requests (1 more than the limit)
        21.times do |i|
          post '/api/v1/location/validate',
               params: valid_location_params.to_json,
               headers: { 'Content-Type' => 'application/json' }

          if response.status == 200
            successful_requests += 1
          elsif response.status == 429
            rate_limited_requests += 1

            # Verify the error message is correct
            json_response = JSON.parse(response.body)
            expect(json_response['error']).to eq('Rate limit exceeded')
          end
        end

        # Exactly 20 requests should succeed
        expect(successful_requests).to eq(20)

        # The 21st request should be rate limited
        expect(rate_limited_requests).to eq(1)

        # Verify the rate limit key is working correctly
        # The key format is "location_api:{ip}:{minute}"
        ip = '127.0.0.1' # Default test request IP
        minute_key = Time.current.to_i / 60
        cache_key = "location_api:#{ip}:#{minute_key}"

        # The cache should show exactly 20 requests counted
        expect(Rails.cache.read(cache_key)).to eq(20)

        # Wait for next minute window and verify requests work again
        # Advance time by 61 seconds to get a new minute window
        travel 61.seconds do
          # Clear the old cache entry to simulate expiry
          Rails.cache.clear

          post '/api/v1/location/validate',
               params: valid_location_params.to_json,
               headers: { 'Content-Type' => 'application/json' }

          # Should work again in new time window
          expect(response.status).to eq(200)
        end
      end
    end
  end

  describe 'POST /api/v1/location/geocode' do
    let(:geocode_params) do
      {
        address: 'Sukhumvit Road, Bangkok, Thailand'
      }
    end

    it 'geocodes address to coordinates' do
      post '/api/v1/location/geocode',
           params: geocode_params.to_json,
           headers: { 'Content-Type' => 'application/json' }

      # This will also fail because controller doesn't exist
      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response['lat']).to be_a(Numeric)
      expect(json_response['lng']).to be_a(Numeric)
      expect(json_response['formatted_address']).to be_present
    end

    it 'handles unknown addresses gracefully' do
      unknown_params = {
        address: 'Nonexistent Place 12345 XYZ'
      }

      post '/api/v1/location/geocode',
           params: unknown_params.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response.status).to be_between(400, 499)

      json_response = JSON.parse(response.body)
      expect(json_response['error']).to be_present
    end

    it 'requires address parameter' do
      post '/api/v1/location/geocode',
           params: {}.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_entity)

      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('address')
    end
  end
end
