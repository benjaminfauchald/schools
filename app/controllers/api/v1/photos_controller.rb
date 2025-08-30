require 'net/http'

class Api::V1::PhotosController < ApplicationController
  # Skip CSRF for API endpoints
  skip_before_action :verify_authenticity_token
  
  def proxy
    photo_reference = params[:photo_reference]
    max_width = params[:max_width] || 400
    
    return head :bad_request unless photo_reference.present?
    
    # Get API key
    api_key = Rails.application.credentials.google_places_api_key || ENV['GOOGLE_PLACES_API_KEY']
    return head :service_unavailable unless api_key.present?
    
    # Construct Google Places Photo URL
    google_url = "https://maps.googleapis.com/maps/api/place/photo?photoreference=#{photo_reference}&maxwidth=#{max_width}&key=#{api_key}"
    
    begin
      # Fetch the image from Google Places API
      response = Net::HTTP.get_response(URI(google_url))
      
      if response.code == '200'
        # Set appropriate headers and serve the image
        send_data response.body,
                  type: response['Content-Type'] || 'image/jpeg',
                  disposition: 'inline',
                  filename: "school_photo_#{photo_reference.first(10)}.jpg"
      else
        # Return a 1x1 transparent pixel if image fails
        head :not_found
      end
    rescue StandardError => e
      Rails.logger.error "Photo proxy error: #{e.message}"
      head :internal_server_error
    end
  end
end