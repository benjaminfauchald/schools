namespace :youtube do
  desc "Extract transcripts for a specific place by ID (also searches schools)"
  task :extract_transcripts, [:place_id, :max_results] => :environment do |t, args|
    place_id = args[:place_id]
    max_results = (args[:max_results] || 10).to_i
    
    if place_id.blank?
      puts "❌ Please provide a place ID: rails youtube:extract_transcripts[123]"
      puts "   Optional: rails youtube:extract_transcripts[123,20] (to process 20 videos)"
      puts "   Use rails youtube:list_places to see available places and schools"
      exit
    end
    
    place = Place.find_by(id: place_id)
    unless place
      puts "❌ Place with ID #{place_id} not found"
      exit
    end
    
    # Check if place has YouTube URL, if not check associated school
    youtube_url = place.youtube_url
    source_type = "place"
    
    if youtube_url.blank? && place.school.present?
      youtube_url = place.school.youtube_url
      source_type = "school"
    end
    
    if youtube_url.blank?
      puts "❌ No YouTube URL found for place '#{place.name}'"
      if place.school.present?
        puts "   Checked both place and associated school: #{place.school.name}"
      end
      puts "   Please add a YouTube channel URL to the place or school first"
      exit
    end
    
    puts "🎬 Processing YouTube transcripts for: #{place.name}"
    if source_type == "school"
      puts "   YouTube URL source: School (#{place.school.name})"
    else
      puts "   YouTube URL source: Place"
    end
    puts "   YouTube URL: #{youtube_url}"
    puts "   Max videos: #{max_results}"
    puts ""
    
    service = YoutubeService.new
    
    # Test API connectivity first
    transcript_service = YoutubeTranscriptService.new
    connection_test = transcript_service.test_connection
    
    unless connection_test[:success]
      puts "❌ Supadata API connection failed: #{connection_test[:message]}"
      puts "   Please check your SUPADATA_API_KEY environment variable"
      exit
    end
    
    puts "✅ API connection successful"
    puts ""
    
    begin
      result = service.fetch_and_process_transcripts(
        place, 
        place.youtube_url, 
        {
          max_results: max_results,
          extract_transcripts: true,
          api_delay: 2,
          force_refresh: false
        }
      )
      
      if result[:success]
        puts "✅ Successfully queued transcript extraction!"
        puts "   Channel ID: #{result[:channel_id]}"
        puts "   Videos found: #{result[:total_videos]}"
        puts "   Transcripts queued: #{result[:transcript_extraction_queued] ? 'Yes' : 'No'}"
        puts ""
        puts "🔄 Processing will continue in the background..."
        puts "   Check the logs or admin interface to monitor progress"
      else
        puts "❌ Failed to process YouTube channel: #{result[:error]}"
      end
      
    rescue => e
      puts "❌ Error occurred: #{e.message}"
      puts e.backtrace.first(5).join("\n") if ENV['DEBUG']
    end
  end
  
  desc "Check transcript processing status for a place"
  task :status, [:place_id] => :environment do |t, args|
    place_id = args[:place_id]
    
    if place_id.blank?
      puts "❌ Please provide a place ID: rails youtube:status[123]"
      exit
    end
    
    place = Place.find_by(id: place_id)
    unless place
      puts "❌ Place with ID #{place_id} not found"
      exit
    end
    
    puts "📊 YouTube Transcript Status for: #{place.name}"
    puts "=" * 50
    
    if place.youtube_url.present?
      puts "YouTube URL: #{place.youtube_url}"
      
      service = YoutubeService.new
      stats = service.channel_stats(place)
      
      if stats[:success]
        puts "Channel has videos: #{stats[:channel_has_videos] ? 'Yes' : 'No'}"
        puts ""
        puts "📈 Processing Statistics:"
        puts "  Total transcripts: #{stats[:existing_transcripts]}"
        puts "  Processed transcripts: #{stats[:processed_transcripts]}"
        puts "  Completion rate: #{stats[:processing_completion]}%"
        
        if stats[:sample_videos].any?
          puts ""
          puts "🎥 Sample videos from channel:"
          stats[:sample_videos].each_with_index do |video, index|
            puts "  #{index + 1}. #{video[:title]}"
            puts "     Video ID: #{video[:video_id]}"
            puts "     Duration: #{YoutubeService.parse_duration(video[:duration])}" if video[:duration]
            puts "     Views: #{YoutubeService.format_view_count(video[:view_count])}" if video[:view_count]
            
            # Check if transcript exists
            transcript = place.transcripts.find_by(youtube_video_id: video[:video_id])
            if transcript
              puts "     Transcript: ✅ #{transcript.processed? ? 'Processed' : 'Pending processing'}"
            else
              puts "     Transcript: ❌ Not extracted"
            end
            puts ""
          end
        end
      else
        puts "❌ Could not fetch channel information: #{stats[:error]}"
      end
    else
      puts "❌ No YouTube URL configured for this place"
    end
    
    # Show recent transcripts
    recent_transcripts = place.transcripts.order(created_at: :desc).limit(5)
    if recent_transcripts.any?
      puts ""
      puts "📝 Recent Transcripts:"
      recent_transcripts.each do |transcript|
        status = transcript.processed? ? "✅ Processed" : "⏳ Pending"
        segments = transcript.segment_count > 0 ? " (#{transcript.segment_count} segments)" : ""
        puts "  • #{transcript.video_title.truncate(60)} #{status}#{segments}"
        puts "    Created: #{transcript.created_at.strftime('%Y-%m-%d %H:%M')}"
        puts ""
      end
    end
  end
  
  desc "List all places and schools with YouTube URLs"
  task :list_places => :environment do
    places_with_youtube = Place.where.not(youtube_url: [nil, ''])
    schools_with_youtube = School.where.not(youtube_url: [nil, ''])
    
    total_count = places_with_youtube.count + schools_with_youtube.count
    
    if total_count == 0
      puts "❌ No places or schools found with YouTube URLs"
      puts "   Add YouTube channel URLs to places or schools to enable transcript extraction"
      puts ""
      puts "💡 Quick setup:"
      puts "   1. Find a school: School.first"
      puts "   2. Add YouTube URL: school.update(youtube_url: 'https://youtube.com/@channelname')"
      puts "   3. Run: rails youtube:extract_transcripts[place_id]"
    else
      puts "🎬 Places and Schools with YouTube Channels (#{total_count} total):"
      puts "=" * 70
      
      if places_with_youtube.any?
        puts ""
        puts "📍 PLACES (#{places_with_youtube.count}):"
        places_with_youtube.each do |place|
          transcript_count = place.transcripts.count
          processed_count = place.transcripts.processed.count
          
          puts "  Place ID: #{place.id} - #{place.name}"
          puts "    YouTube: #{place.youtube_url}"
          puts "    Transcripts: #{processed_count}/#{transcript_count} processed"
          puts "    Extract: rails youtube:extract_transcripts[#{place.id}]"
          puts ""
        end
      end
      
      if schools_with_youtube.any?
        puts ""
        puts "🏫 SCHOOLS (#{schools_with_youtube.count}):"
        schools_with_youtube.each do |school|
          place = school.place
          if place
            transcript_count = place.transcripts.count
            processed_count = place.transcripts.processed.count
            
            puts "  School ID: #{school.id} (Place ID: #{place.id}) - #{school.name}"
            puts "    YouTube: #{school.youtube_url}"
            puts "    Transcripts: #{processed_count}/#{transcript_count} processed"
            puts "    Extract: rails youtube:extract_transcripts[#{place.id}]"
          else
            puts "  School ID: #{school.id} - #{school.name}"
            puts "    YouTube: #{school.youtube_url}"
            puts "    ⚠️  No associated place found - cannot extract transcripts"
          end
          puts ""
        end
      end
    end
  end
  
  desc "Test Supadata API connection"
  task :test_api => :environment do
    puts "🔌 Testing Supadata API connection..."
    
    begin
      service = YoutubeTranscriptService.new
      result = service.test_connection
      
      if result[:success]
        puts "✅ API connection successful!"
        puts "   #{result[:message]}"
      else
        puts "❌ API connection failed!"
        puts "   #{result[:message]}"
        puts ""
        puts "🔧 Troubleshooting:"
        puts "   1. Check your SUPADATA_API_KEY environment variable"
        puts "   2. Ensure you have internet connectivity"
        puts "   3. Verify the API key is valid and active"
      end
      
    rescue => e
      puts "❌ Error testing API: #{e.message}"
    end
  end
  
  desc "Force refresh transcripts for a place (re-extract existing ones)"
  task :refresh_transcripts, [:place_id, :max_results] => :environment do |t, args|
    place_id = args[:place_id]
    max_results = (args[:max_results] || 10).to_i
    
    if place_id.blank?
      puts "❌ Please provide a place ID: rails youtube:refresh_transcripts[123]"
      exit
    end
    
    place = Place.find_by(id: place_id)
    unless place
      puts "❌ Place with ID #{place_id} not found"
      exit
    end
    
    puts "🔄 Force refreshing transcripts for: #{place.name}"
    puts "   This will re-extract existing transcripts"
    puts ""
    
    service = YoutubeService.new
    
    begin
      result = service.fetch_and_process_transcripts(
        place, 
        place.youtube_url, 
        {
          max_results: max_results,
          extract_transcripts: true,
          api_delay: 3, # Slightly longer delay for refresh
          force_refresh: true
        }
      )
      
      if result[:success]
        puts "✅ Successfully queued transcript refresh!"
        puts "   Videos to refresh: #{result[:total_videos]}"
      else
        puts "❌ Failed to queue refresh: #{result[:error]}"
      end
      
    rescue => e
      puts "❌ Error occurred: #{e.message}"
    end
  end
end