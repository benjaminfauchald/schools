require 'net/http'
require 'cgi'
require 'openssl'

class Api::V1::PhotosController < ApplicationController
  # Skip CSRF for API endpoints
  skip_before_action :verify_authenticity_token
  
  def proxy
    photo_reference = CGI.unescape(params[:photo_reference].to_s)
    max_width = params[:max_width] || 400
    
    return head :bad_request unless photo_reference.present?
    
    # Get API key
    api_key = Rails.application.credentials.google_places_api_key || ENV['GOOGLE_PLACES_API_KEY']
    return head :service_unavailable unless api_key.present?
    
    # Construct Google Places Photo URL
    google_url = "https://maps.googleapis.com/maps/api/place/photo?photoreference=#{photo_reference}&maxwidth=#{max_width}&key=#{api_key}"
    
    begin
      # Fetch the image from Google Places API (follow redirects)
      response = Net::HTTP.get_response(URI(google_url))
      
      # Handle redirect (Google Places API returns 302 to actual image URL)
      if response.code == '302' && response['Location']
        begin
          redirect_uri = URI(response['Location'])
          http = Net::HTTP.new(redirect_uri.host, redirect_uri.port)
          http.use_ssl = true if redirect_uri.scheme == 'https'
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE if redirect_uri.scheme == 'https'
          
          request = Net::HTTP::Get.new(redirect_uri)
          final_response = http.request(request)
          response = final_response
        rescue => redirect_error
          head :internal_server_error
          return
        end
      end
      
      if response.code == '200'
        # Set appropriate headers and serve the image
        send_data response.body,
                  type: response['Content-Type'] || 'image/jpeg',
                  disposition: 'inline',
                  filename: "school_photo_#{photo_reference.first(10)}.jpg"
      else
        head :not_found
      end
    rescue StandardError => e
      head :internal_server_error
    end
  end
end