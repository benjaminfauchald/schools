require 'net/http'
require 'uri'
require 'json'
require 'cgi'

module Admin
  class GoogleMapImportsController < Admin::ApplicationController
    def index
      # Show import history or redirect to new import form
      redirect_to new_admin_google_map_import_path
    end
    
    def new
      # Show the import form
    end
    
    def create
      @google_maps_url = params[:google_maps_url]&.strip
      
      if @google_maps_url.blank?
        flash.now[:alert] = "Please enter a Google Maps URL"
        render :new and return
      end
      
      # Extract place ID from the URL
      place_id = extract_place_id_from_url(@google_maps_url)
      
      if place_id.blank?
        flash.now[:alert] = "Could not extract place ID from the provided URL. Please check the URL format."
        render :new and return
      end
      
      begin
        # Import the place using existing infrastructure
        result = import_google_place(place_id)
        
        if result[:success]
          flash[:notice] = "✅ Successfully imported: #{result[:place_name]} → #{result[:school_name]}"
          redirect_to admin_schools_path
        else
          flash.now[:alert] = "❌ Import failed: #{result[:error]}"
          render :new
        end
        
      rescue => e
        Rails.logger.error "Google Maps Import Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        flash.now[:alert] = "An error occurred during import: #{e.message}"
        render :new
      end
    end
    
    private
    
    def extract_place_id_from_url(url)
      # Handle different Google Maps URL formats
      patterns = [
        # Standard place URL: https://www.google.com/maps/place/.../@lat,lng,zoom/data=...!3m1!4b1!4m6!3m5!1s0x123456789:0xabcdef123456!8m2!3d13.123!4d100.456!16s%2Fm%2F0123abc
        /place_id:([A-Za-z0-9_-]{20,})/,
        # Place ID in data parameter: !1s0x123456:0xabcd123!2m2!1d100.456!2d13.123!3m1!4b1!4m6!3m5!1s(ChIJ[A-Za-z0-9_-]{20,})
        /1s(ChIJ[A-Za-z0-9_-]{20,})/,
        # Direct place ID URLs
        /\/place\/[^\/]*\/@[^\/]*\/data=.*1s([A-Za-z0-9_-]{20,})/,
        # Search URLs with place data
        /maps\/search\/[^\/]*\/@[^,]*,[^,]*,[^\/]*\/data=.*1s([A-Za-z0-9_-]{20,})/
      ]
      
      patterns.each do |pattern|
        match = url.match(pattern)
        return match[1] if match
      end
      
      # If no pattern matches, try to extract any ChIJ... identifier
      chij_match = url.match(/ChIJ[A-Za-z0-9_-]{20,}/)
      return chij_match[0] if chij_match
      
      # Handle search URLs - extract search query and coordinates
      search_match = url.match(/maps\/search\/([^\/]+)\/@([^,]+),([^,]+),/)
      if search_match
        query = CGI.unescape(search_match[1])
        lat = search_match[2].to_f
        lng = search_match[3].to_f
        return find_place_from_search(query, lat, lng)
      end
      
      nil
    end
    
    def find_place_from_search(query, lat, lng)
      api_key = ENV['GOOGLE_PLACES_API_KEY']
      return nil if api_key.blank?
      
      # Use Text Search API to find the place
      url = "https://maps.googleapis.com/maps/api/place/textsearch/json"
      params = {
        query: query,
        location: "#{lat},#{lng}",
        radius: 5000, # 5km radius
        key: api_key
      }
      
      uri = URI(url)
      uri.query = URI.encode_www_form(params)
      
      response = Net::HTTP.get_response(uri)
      api_response = JSON.parse(response.body)
      
      if api_response['status'] == 'OK' && api_response['results']&.any?
        # Return the place_id of the first result
        return api_response['results'].first['place_id']
      end
      
      nil
    rescue => e
      Rails.logger.error "Text search error: #{e.message}"
      nil
    end
    
    def import_google_place(place_id)
      # Check if place already exists
      existing_place = Place.find_by(place_id: place_id)
      if existing_place
        school = existing_place.school
        if school
          return {
            success: true,
            place_name: existing_place.name,
            school_name: school.name,
            message: "Place already exists and is linked to school"
          }
        end
      end
      
      # Fetch place details from Google Places API
      api_key = ENV['GOOGLE_PLACES_API_KEY']
      raise "Google Places API key not configured" if api_key.blank?
      
      url = "https://maps.googleapis.com/maps/api/place/details/json"
      params = {
        place_id: place_id,
        fields: 'place_id,name,formatted_address,geometry,rating,user_ratings_total,formatted_phone_number,website,opening_hours,types,photos,reviews,business_status,price_level,vicinity,international_phone_number,url,icon,editorial_summary,wheelchair_accessible_entrance',
        key: api_key
      }
      
      uri = URI(url)
      uri.query = URI.encode_www_form(params)
      
      response = Net::HTTP.get_response(uri)
      api_response = JSON.parse(response.body)
      
      if api_response['status'] != 'OK'
        raise "Google Places API error: #{api_response['status']} - #{api_response['error_message']}"
      end
      
      # Create or update Place record
      place = if existing_place
        Place.update_from_google_api(place_id, api_response)
      else
        Place.create_from_google_api(api_response)
      end
      
      # Convert Place to School using existing infrastructure
      school = convert_place_to_school(place)
      
      {
        success: true,
        place: place,
        school: school,
        place_name: place.name,
        school_name: school.name
      }
    end
    
    def convert_place_to_school(place)
      # Use existing SchoolPlacesSyncer logic
      return place.school if place.school # Already has a school
      
      # Create new School from Place data (without coordinates first)
      school_data = {
        name: place.name,
        place: place,
        status: 'draft', # Start as draft for admin review
        about: place.editorial_summary,
        phone: place.formatted_phone_number,
        website_url: place.website,
        address_line_1: extract_street_from_place(place),
        district: extract_district_from_place(place),
        province: extract_province_from_place(place),
        postcode: extract_postcode_from_place(place),
        country_code: 'TH' # Default to Thailand
      }
      
      school = School.create!(school_data)
      
      # Update coordinates separately to trigger geography update callback
      if place.lat.present? && place.lng.present?
        school.update!(lat: place.lat, lng: place.lng)
      end
      
      school
    end
    
    def extract_street_from_place(place)
      return nil unless place.address_components
      
      street_component = place.address_components.find { |c| c['types'].include?('route') }
      street_number = place.address_components.find { |c| c['types'].include?('street_number') }
      
      [street_number&.dig('long_name'), street_component&.dig('long_name')].compact.join(' ')
    end
    
    def extract_district_from_place(place)
      return nil unless place.address_components
      
      district_component = place.address_components.find do |c| 
        c['types'].include?('sublocality_level_1') || c['types'].include?('administrative_area_level_2')
      end
      district_component&.dig('long_name')
    end
    
    def extract_province_from_place(place)
      return nil unless place.address_components
      
      province_component = place.address_components.find { |c| c['types'].include?('administrative_area_level_1') }
      province_component&.dig('long_name')
    end
    
    def extract_postcode_from_place(place)
      return nil unless place.address_components
      
      postal_component = place.address_components.find { |c| c['types'].include?('postal_code') }
      postal_component&.dig('long_name')
    end
  end
end