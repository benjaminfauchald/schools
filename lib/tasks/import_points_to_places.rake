# Save this as lib/tasks/import_points_to_places.rake

require 'net/http'
require 'uri'
require 'json'

namespace :data do
  desc "Import Points to Places using Google Places API"
  task import_points_to_places: :environment do
    # Configuration constants
    GOOGLE_PLACES_API_KEY = ENV['GOOGLE_PLACES_API_KEY']
    BATCH_SIZE = 10
    DELAY_BETWEEN_REQUESTS = 0.2  # Increased to avoid rate limits
    DELAY_BETWEEN_BATCHES = 2
    SEARCH_RADIUS = 150  # meters
    
    # Initialize statistics
    @stats = {
      total_schools: 0,
      processed: 0,
      success: 0,
      failed: 0,
      skipped: 0,
      refreshed: 0,
      api_errors: 0,
      no_matches: 0,
      start_time: Time.current
    }
    
    # Google Places API helper methods
    def nearby_search(lat, lng, radius: SEARCH_RADIUS, type: 'school')
      url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
      params = {
        location: "#{lat},#{lng}",
        radius: radius,
        type: type,
        key: GOOGLE_PLACES_API_KEY
      }
      
      uri = URI(url)
      uri.query = URI.encode_www_form(params)
      
      response = Net::HTTP.get_response(uri)
      sleep(DELAY_BETWEEN_REQUESTS)
      JSON.parse(response.body)
    end

    def place_details(place_id)
      url = "https://maps.googleapis.com/maps/api/place/details/json"
      params = {
        place_id: place_id,
        fields: 'place_id,name,formatted_address,geometry,rating,user_ratings_total,formatted_phone_number,website,opening_hours,types,photos,reviews,business_status,price_level,vicinity,international_phone_number,url,icon,editorial_summary,wheelchair_accessible_entrance',
        key: GOOGLE_PLACES_API_KEY
      }
      
      uri = URI(url)
      uri.query = URI.encode_www_form(params)
      
      response = Net::HTTP.get_response(uri)
      sleep(DELAY_BETWEEN_REQUESTS)
      JSON.parse(response.body)
    end

    def calculate_distance(lat1, lng1, lat2, lng2)
      rad_per_deg = Math::PI / 180
      rkm = 6371000  # Earth radius in meters

      dlat_rad = (lat2-lat1) * rad_per_deg
      dlng_rad = (lng2-lng1) * rad_per_deg
      
      lat1_rad, lat2_rad = lat1 * rad_per_deg, lat2 * rad_per_deg
      
      a = Math.sin(dlat_rad/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlng_rad/2)**2
      c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
      
      rkm * c
    end

    def find_best_match(point, nearby_places)
      return nil if nearby_places.empty?
      
      nearby_places.min_by do |place|
        place_lat = place.dig('geometry', 'location', 'lat')
        place_lng = place.dig('geometry', 'location', 'lng')
        calculate_distance(point.lat, point.lon, place_lat, place_lng)
      end
    end
    
    def process_school(school)
      begin
        @stats[:processed] += 1
        
        # Check if school already has Place data that's still valid
        existing_place = school.places.first
        if existing_place && !existing_place.needs_refresh?
          days_old = existing_place.days_since_last_fetch&.round(1)
          puts "⏭️  Skipped: #{school.name.truncate(40)} (Place data is #{days_old} days old, still valid)"
          @stats[:skipped] += 1
          return :skipped
        elsif existing_place && existing_place.needs_refresh?
          days_old = existing_place.days_since_last_fetch&.round(1)
          puts "🔄 Refreshing: #{school.name.truncate(40)} (Place data is #{days_old} days old, expired)"
        end
        
        # Search for nearby schools
        nearby_response = nearby_search(school.lat, school.lon)
        
        if nearby_response['status'] != 'OK'
          puts "🚫 API Error: #{school.name.truncate(40)} - #{nearby_response['status']}"
          @stats[:api_errors] += 1
          return :api_error
        end
        
        nearby_schools = nearby_response['results'] || []
        
        if nearby_schools.empty?
          puts "❌ No matches: #{school.name.truncate(40)}"
          @stats[:no_matches] += 1
          return :no_matches
        end
        
        # Find best match
        best_match = find_best_match(school, nearby_schools)
        return :no_matches unless best_match
        
        # Get detailed information
        details_response = place_details(best_match['place_id'])
        
        if details_response['status'] != 'OK'
          puts "🚫 Details Error: #{school.name.truncate(40)} - #{details_response['status']}"
          @stats[:api_errors] += 1
          return :details_error
        end
        
        # Create or update Place record
        if existing_place
          place = Place.update_from_google_api(existing_place.place_id, details_response, school)
        else
          place = Place.create_from_google_api(details_response, school)
        end
        
        # Calculate distance for logging
        distance = calculate_distance(
          school.lat, school.lon,
          place.lat, place.lng
        ).round(1)
        
        if existing_place
          puts "🔄 Refreshed: #{school.name.truncate(40)} (#{distance}m away, rating: #{place.rating || 'N/A'})"
          @stats[:refreshed] += 1
          return :refreshed
        else
          puts "✅ Created: #{school.name.truncate(40)} (#{distance}m away, rating: #{place.rating || 'N/A'})"
          @stats[:success] += 1
          return :success
        end
        
      rescue => e
        puts "💥 Exception: #{school.name.truncate(40)} - #{e.message.truncate(50)}"
        @stats[:failed] += 1
        return :exception
      end
    end
    
    def print_progress_report
      if @stats[:processed] > 0
        success_rate = (@stats[:success].to_f / @stats[:processed] * 100).round(1)
        elapsed = Time.current - @stats[:start_time]
        rate = @stats[:processed] / elapsed * 60  # per minute
        
        puts "\n📊 Progress Report:"
        puts "   Processed: #{@stats[:processed]}/#{@stats[:total_schools]}"
        puts "   ✅ Created: #{@stats[:success]} (#{success_rate}%)"
        puts "   🔄 Refreshed: #{@stats[:refreshed]}"
        puts "   ⏭️  Skipped: #{@stats[:skipped]}"
        puts "   ❌ Failed: #{@stats[:failed]}"
        puts "   🚫 API Errors: #{@stats[:api_errors]}"
        puts "   🔍 No Matches: #{@stats[:no_matches]}"
        puts "   ⏱️  Elapsed: #{elapsed.round(1)}s (#{rate.round(1)} schools/min)"
        
        if @stats[:processed] < @stats[:total_schools]
          remaining = @stats[:total_schools] - @stats[:processed]
          eta = remaining / rate
          puts "   🕐 ETA: #{eta.round(1)} minutes"
        end
      end
    end
    
    def print_final_summary
      total_time = Time.current - @stats[:start_time]      
      puts "\n" + "🎉" * 20
      puts "PROCESSING COMPLETE!"
      puts "🎉" * 20
      puts "📊 Final Statistics:"
      puts "   Total schools: #{@stats[:total_schools]}"
      puts "   ✅ Successfully created: #{@stats[:success]}"
      puts "   🔄 Refreshed (30-day expired): #{@stats[:refreshed]}"
      puts "   ⏭️  Skipped (data still valid): #{@stats[:skipped]}"
      puts "   ❌ Failed: #{@stats[:failed]}"
      puts "   🚫 API Errors: #{@stats[:api_errors]}"
      puts "   🔍 No Matches Found: #{@stats[:no_matches]}"
      puts "   ⏱️  Total time: #{(total_time/60).round(1)} minutes"
      puts "   📊 Success rate: #{(@stats[:success].to_f / (@stats[:processed] - @stats[:skipped]) * 100).round(1)}%"
      
      # Database statistics
      places_created = Place.count
      schools_with_places = Point.schools.joins(:places).count
      
      puts "\n📈 Database Results:"
      puts "   Total Places created: #{places_created}"
      puts "   Schools with Google data: #{schools_with_places}"
      puts "   Average rating: #{Place.where.not(rating: nil).average(:rating)&.round(2)}"
      puts "   Places with reviews: #{Place.where.not(reviews: [nil, '[]']).count}"
      puts "   Places with photos: #{Place.where.not(photos: [nil, '[]']).count}"
      puts "🎉" * 20
    end
    
    # Main processing method
    def process_all_schools
      # Check API key
      if GOOGLE_PLACES_API_KEY.blank?
        puts "❌ Google Places API key not found!"
        puts "Set it with: export GOOGLE_PLACES_API_KEY=your_api_key"
        return
      end
      
      # Get all schools
      schools = Point.schools.with_names.order(:id)
      @stats[:total_schools] = schools.count
      
      # Check Google Maps compliance status
      total_places = Point.schools.joins(:places).count
      compliant_places = Point.schools.joins(:places).merge(Place.google_maps_compliant).count
      expired_places = Point.schools.joins(:places).merge(Place.google_maps_expired).count
      schools_without_places = @stats[:total_schools] - total_places
      
      puts "🚀 Starting Google Places import for #{@stats[:total_schools]} schools"
      puts "📊 Google Maps API Compliance Status:"
      puts "   ✅ Schools with valid Places data (< 30 days): #{compliant_places}"
      puts "   🔄 Schools with expired Places data (> 30 days): #{expired_places}"
      puts "   ❌ Schools without Places data: #{schools_without_places}"
      puts "🎯 Schools to process: #{expired_places + schools_without_places}"
      puts "⚙️  Batch size: #{BATCH_SIZE}"
      puts "⏱️  Delay between requests: #{DELAY_BETWEEN_REQUESTS}s"
      puts "⏱️  Delay between batches: #{DELAY_BETWEEN_BATCHES}s"
      
      if expired_places + schools_without_places == 0
        puts "✅ All schools have valid Google Places data (compliant with 30-day policy)!"
        return
      end
      
      puts "\n🚦 Starting in 3 seconds..."
      sleep(3)
      
      # Process in batches
      batch_index = 0
      total_batches = (schools.count.to_f/BATCH_SIZE).ceil
      
      schools.in_batches(of: BATCH_SIZE) do |batch|
        batch_index += 1
        puts "\n📦 Processing batch #{batch_index}/#{total_batches}"
        puts "-" * 60
        
        batch.each do |school|
          process_school(school)
        end
        
        # Progress report after each batch
        print_progress_report
        
        # Delay between batches (except for the last one)
        unless batch_index == total_batches
          puts "😴 Sleeping #{DELAY_BETWEEN_BATCHES}s before next batch...\n"
          sleep(DELAY_BETWEEN_BATCHES)
        end
      end
      
      print_final_summary
    end
    
    # Execute the main processing
    process_all_schools
  end
end