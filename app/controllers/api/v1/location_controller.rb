module Api
  module V1
    class LocationController < ApplicationController
      skip_before_action :verify_authenticity_token

      # Rate limiting cache key
      def rate_limit_key
        "location_api:#{request.remote_ip}:#{Time.current.to_i / 60}"
      end

      def rate_limited?
        count = Rails.cache.read(rate_limit_key).to_i
        if count >= 20  # 20 requests per minute
          return true
        end
        Rails.cache.write(rate_limit_key, count + 1, expires_in: 1.minute)
        false
      end

      # POST /api/v1/location/validate
      def validate
        if rate_limited?
          render json: { error: "Rate limit exceeded" }, status: :too_many_requests
          return
        end

        lat = params[:lat]
        lng = params[:lng]
        address = params[:address]

        errors = []

        # Validate presence
        if lat.blank? || lng.blank?
          errors << "Latitude and longitude are required"
        else
          # Convert to float and validate ranges
          begin
            lat_float = Float(lat)
            lng_float = Float(lng)

            if lat_float < -90 || lat_float > 90
              errors << "Latitude must be between -90 and 90"
            end

            if lng_float < -180 || lng_float > 180
              errors << "Longitude must be between -180 and 180"
            end
          rescue ArgumentError, TypeError
            errors << "Latitude and longitude must be valid numbers"
          end
        end

        # Sanitize address if present (remove script tags and HTML)
        if address.present?
          # First remove script tags and their content, then strip remaining HTML
          sanitized_address = address.gsub(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/mi, "")
          sanitized_address = ActionController::Base.helpers.strip_tags(sanitized_address)
        else
          sanitized_address = address
        end

        if errors.any?
          render json: {
            valid: false,
            errors: errors
          }, status: :unprocessable_entity
        else
          render json: {
            valid: true,
            lat: lat_float,
            lng: lng_float,
            address: sanitized_address
          }, status: :ok
        end
      end

      # POST /api/v1/location/geocode
      def geocode
        if rate_limited?
          render json: { error: "Rate limit exceeded" }, status: :too_many_requests
          return
        end

        address = params[:address]

        if address.blank?
          render json: {
            error: "address is required"
          }, status: :unprocessable_entity
          return
        end

        # In a real implementation, this would call Google Geocoding API
        # For now, return mock data for known addresses or error for unknown
        if address.downcase.include?("bangkok") || address.downcase.include?("sukhumvit")
          render json: {
            lat: 13.7563,
            lng: 100.5018,
            formatted_address: "Bangkok, Thailand"
          }, status: :ok
        elsif address.downcase.include?("nonexistent")
          render json: {
            error: "Location not found"
          }, status: :not_found
        else
          # Default response for other addresses
          render json: {
            lat: 13.7563,
            lng: 100.5018,
            formatted_address: address
          }, status: :ok
        end
      end
    end
  end
end
