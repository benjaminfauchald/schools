# Save this as lib/tasks/import_points_to_places.rake

namespace :data do
  desc "Import Points to Places using Google Places API"
  task import_points_to_places: :environment do
    # Configuration constants
    GOOGLE_PLACES_API_KEY = ENV['GOOGLE_PLACES_API_KEY']
    BATCH_SIZE = 10
    DELAY_BETWEEN_REQUESTS = 0.1
    DELAY_BETWEEN_BATCHES = 5

    # Initialize statistics
    @stats = {
      total_schools: 0,
      processed: 0,
      success: 0,
      failed: 0,
      start_time: Time.current
    }

    def process_school(school)
      begin
        @stats[:processed] += 1

        # Your school processing logic here
        # For example:
        # result = call_google_places_api(school)
        # create_place_from_result(result, school)

        puts "✅ Processed: #{school.name} (#{school.id})"
        @stats[:success] += 1

        # Delay between requests
        sleep(DELAY_BETWEEN_REQUESTS)

      rescue => e
        puts "❌ Failed: #{school.name} (#{school.id}) - #{e.message}"
        @stats[:failed] += 1
      end
    end

    def print_progress_report
      success_rate = (@stats[:success].to_f / @stats[:processed] * 100).round(1)
      puts "\n📊 Progress Report:"
      puts "   Processed: #{@stats[:processed]}/#{@stats[:total_schools]}"
      puts "   Success: #{@stats[:success]} (#{success_rate}%)"
      puts "   Failed: #{@stats[:failed]}"
      puts "   Elapsed: #{(Time.current - @stats[:start_time]).round(1)}s"
    end

    def print_final_summary
      total_time = Time.current - @stats[:start_time]
      success_rate = (@stats[:success].to_f / @stats[:total_schools] * 100).round(1)

      puts "\n" + "=" * 60
      puts "🎉 PROCESSING COMPLETE!"
      puts "=" * 60
      puts "📊 Final Statistics:"
      puts "   Total schools: #{@stats[:total_schools]}"
      puts "   Successfully processed: #{@stats[:success]} (#{success_rate}%)"
      puts "   Failed: #{@stats[:failed]}"
      puts "   Total time: #{total_time.round(1)}s"
      puts "   Average per school: #{(total_time / @stats[:total_schools]).round(2)}s"
      puts "=" * 60
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

      puts "🚀 Starting bulk processing of #{@stats[:total_schools]} schools"
      puts "⚙️  Batch size: #{BATCH_SIZE}"
      puts "⏱️  Delay between requests: #{DELAY_BETWEEN_REQUESTS}s"
      puts "⏱️  Delay between batches: #{DELAY_BETWEEN_BATCHES}s"
      puts "📊 Progress will be shown every #{BATCH_SIZE} schools\n"

      # Process in batches with manual indexing
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
