# lib/tasks/data/web_page_to_llm_data.rake
#
# Comprehensive school website crawling using Firecrawl with JSON schema extraction
# Extracts structured data for AI processing from school websites
# Bypasses cookie consent issues by prioritizing structured JSON over raw markdown
#
# USAGE EXAMPLES:
#
#   # Standard mode - crawls schools needing updates
#   bin/rails data:web_page_to_llm_data
#
#   # Force update ALL schools with websites (ignores crawl age)
#   FORCE_UPDATE=true bin/rails data:web_page_to_llm_data
#
#   # Preview what would be crawled without making changes
#   DRY_RUN=true bin/rails data:web_page_to_llm_data
#
#   # Combine force update with dry run
#   FORCE_UPDATE=true DRY_RUN=true bin/rails data:web_page_to_llm_data
#
#   # Custom configuration
#   CRAWLING_DELAY=10 CRAWLING_BATCH_SIZE=2 bin/rails data:web_page_to_llm_data

require "json"
require "open3"

namespace :data do
  desc "Crawl school websites to extract LLM-ready structured data using Firecrawl"
  desc "Environment variables:"
  desc "  FORCE_UPDATE=true - Force re-crawl all schools regardless of last crawl date"
  desc "  DRY_RUN=true - Preview mode, no database changes"
  desc "  MAX_CRAWL_AGE_DAYS=30 - Days before re-crawling (default: 30)"
  desc "  CRAWLING_DELAY=5 - Seconds between crawls (default: 5)"
  desc "  CRAWLING_BATCH_SIZE=3 - Schools per batch (default: 3)"
  task web_page_to_llm_data: :environment do
    # Configuration constants
    PYTHON_SCRIPT = Rails.root.join("scripts", "crawl_school_websites.py").to_s
    DELAY_BETWEEN_CRAWLS = ENV.fetch("CRAWLING_DELAY", 5).to_i  # seconds
    BATCH_SIZE = ENV.fetch("CRAWLING_BATCH_SIZE", 3).to_i  # schools per batch
    MAX_CRAWL_AGE_DAYS = ENV.fetch("MAX_CRAWL_AGE_DAYS", 30).to_i
    DRY_RUN = ENV["DRY_RUN"] == "true"
    FORCE_UPDATE = ENV["FORCE_UPDATE"] == "true"

    # Initialize statistics
    @stats = {
      total_schools: 0,
      processed: 0,
      successful_crawls: 0,
      failed_crawls: 0,
      skipped: 0,
      updated_records: 0,
      start_time: Time.current,
      errors: []
    }

    def validate_environment
      puts "🔧 Validating environment setup..."

      # Check Firecrawl API key
      unless ENV["FIRECRAWL_API_KEY"].present?
        puts "❌ FIRECRAWL_API_KEY environment variable not set!"
        puts "   Set it with: export FIRECRAWL_API_KEY=your_api_key"
        exit 1
      end

      # Check Python script exists
      unless File.exist?(PYTHON_SCRIPT)
        puts "❌ Python crawling script not found at: #{PYTHON_SCRIPT}"
        exit 1
      end

      # Test Python script
      stdout, stderr, status = Open3.capture3("python3 #{PYTHON_SCRIPT} --test")
      unless status.success?
        puts "❌ Python script test failed:"
        puts stderr
        exit 1
      end

      puts "✅ Environment validation passed"
    end

    def get_website_url(school)
      # Prefer schools.website_url over places.website
      school.website_url.present? ? school.website_url : school.place&.website
    end

    def get_schools_to_crawl
      puts "📊 Analyzing schools requiring website crawling..."

      # Get all schools with websites (check both places.website AND schools.website_url)
      all_with_websites = School.left_joins(:place).where(
        "places.website IS NOT NULL AND places.website != '' OR schools.website_url IS NOT NULL AND schools.website_url != ''"
      )

      # Handle force update mode
      if FORCE_UPDATE
        puts "⚡ FORCE_UPDATE enabled - will re-crawl ALL schools with websites"
        schools_to_process = all_with_websites
        never_crawled = all_with_websites.where(schools: { website_crawled_at: nil })
        expired_crawls = School.none
        recent_crawls = all_with_websites.where.not(schools: { website_crawled_at: nil })
        failed_crawls = all_with_websites.where(schools: { website_crawling_status: "failed" })
      else
        # Normal mode - respect crawl age and status
        never_crawled = all_with_websites.where(schools: { website_crawled_at: nil })
        expired_crawls = all_with_websites.where(
          "schools.website_crawled_at < ?",
          MAX_CRAWL_AGE_DAYS.days.ago
        )
        recent_crawls = all_with_websites.where(
          "schools.website_crawled_at >= ?",
          MAX_CRAWL_AGE_DAYS.days.ago
        )
        failed_crawls = all_with_websites.where(schools: { website_crawling_status: "failed" })

        # Determine which schools to process
        schools_to_process = never_crawled.or(expired_crawls).or(failed_crawls)
      end

      puts "   📈 Website Crawling Status:"
      puts "   🆕 Never crawled: #{never_crawled.count}"
      puts "   🔄 Expired crawls (>#{MAX_CRAWL_AGE_DAYS} days): #{expired_crawls.count}"
      puts "   ✅ Recent valid crawls: #{recent_crawls.count}"
      puts "   ❌ Previous failures: #{failed_crawls.count}"

      if FORCE_UPDATE
        puts "   ⚡ FORCE_UPDATE: Will crawl ALL #{schools_to_process.count} schools (ignoring age)"
      end

      puts "   🎯 Schools to process: #{schools_to_process.count}"

      if schools_to_process.count == 0
        puts "   ✅ All schools have recent website crawl data!"
        return []
      end

      schools_to_process.includes(:place).order(:id)
    end

    def crawl_school_website(school)
      website_url = get_website_url(school)
      puts "🔍 Crawling: #{school.name&.truncate(40) || "School ##{school.id}"}"
      puts "   🌐 URL: #{website_url}"

      # Update status to 'crawling'
      unless DRY_RUN
        school.update!(
          website_crawling_status: "crawling",
          website_crawling_error: nil
        )
      end

      # Call Python script to crawl the website
      cmd = "python3 #{PYTHON_SCRIPT} --website \"#{website_url}\""
      stdout, stderr, status = Open3.capture3(cmd)

      if status.success?
        # Parse crawl results
        begin
          crawl_result = JSON.parse(stdout)

          if crawl_result["success"]
            unless DRY_RUN
              # Update school with crawl results
              school.update!(
                website_crawled_at: Time.current,
                website_crawling_status: "completed",
                website_pages_found: crawl_result["pages_found"],
                website_crawl_data: crawl_result["raw_data"],
                website_structured_data: crawl_result["structured_data"],
                website_crawling_error: nil
              )
            end

            pages_found = crawl_result["pages_found"]
            structured_sections = crawl_result["structured_data"]&.keys&.count || 0

            puts "   ✅ Success: #{pages_found} pages, #{structured_sections} data sections"
            @stats[:successful_crawls] += 1
            @stats[:updated_records] += 1 unless DRY_RUN

            :success
          else
            error_msg = crawl_result["error"] || "Unknown error"
            puts "   ❌ Crawl failed: #{error_msg.truncate(50)}"

            unless DRY_RUN
              school.update!(
                website_crawling_status: "failed",
                website_crawling_error: error_msg
              )
            end

            @stats[:failed_crawls] += 1
            @stats[:errors] << "#{website_url}: #{error_msg}"
            :failed
          end

        rescue JSON::ParserError => e
          error_msg = "JSON parse error: #{e.message}"
          puts "   💥 #{error_msg}"

          unless DRY_RUN
            school.update!(
              website_crawling_status: "failed",
              website_crawling_error: error_msg
            )
          end

          @stats[:failed_crawls] += 1
          @stats[:errors] << "#{website_url}: #{error_msg}"
          :failed
        end

      else
        error_msg = "Python script failed: #{stderr.truncate(100)}"
        puts "   💥 #{error_msg}"

        unless DRY_RUN
          school.update!(
            website_crawling_status: "failed",
            website_crawling_error: error_msg
          )
        end

        @stats[:failed_crawls] += 1
        @stats[:errors] << "#{website_url}: #{error_msg}"
        :failed
      end
    end

    def print_progress_report
      if @stats[:processed] > 0
        elapsed = Time.current - @stats[:start_time]
        rate = @stats[:processed] / elapsed * 60  # per minute
        success_rate = (@stats[:successful_crawls].to_f / @stats[:processed] * 100).round(1)

        puts "\n📊 Progress Report:"
        puts "   Processed: #{@stats[:processed]}/#{@stats[:total_schools]}"
        puts "   ✅ Successful: #{@stats[:successful_crawls]} (#{success_rate}%)"
        puts "   ❌ Failed: #{@stats[:failed_crawls]}"
        puts "   ⏭️  Skipped: #{@stats[:skipped]}"
        puts "   ⏱️  Rate: #{rate.round(1)} schools/minute"
        puts "   🕐 Elapsed: #{(elapsed / 60).round(1)} minutes"

        if @stats[:processed] < @stats[:total_schools]
          remaining = @stats[:total_schools] - @stats[:processed]
          eta_minutes = remaining / rate
          puts "   ⏰ ETA: #{eta_minutes.round(1)} minutes"
        end
      end
    end

    def print_final_summary
      total_time = Time.current - @stats[:start_time]

      puts "\n" + "🎉" * 25
      puts "WEBSITE CRAWLING COMPLETE!"
      puts "🎉" * 25
      puts "📊 Final Statistics:"
      puts "   📚 Total schools processed: #{@stats[:total_schools]}"
      puts "   ✅ Successfully crawled: #{@stats[:successful_crawls]}"
      puts "   ❌ Failed crawls: #{@stats[:failed_crawls]}"
      puts "   ⏭️  Skipped (valid data): #{@stats[:skipped]}"
      puts "   📝 Database records updated: #{@stats[:updated_records]}"
      puts "   ⏱️  Total processing time: #{(total_time / 60).round(1)} minutes"

      if @stats[:processed] > 0
        success_rate = (@stats[:successful_crawls].to_f / @stats[:processed] * 100)
        puts "   📈 Success rate: #{success_rate.round(1)}%"
      end

      # Database statistics
      total_crawled = School.where.not(website_crawled_at: nil).count
      successful_crawls = School.where(website_crawling_status: "completed").count
      schools_with_websites = School.joins(:place).where.not(places: { website: [ nil, "" ] }).count

      puts "\n📈 Database Status:"
      puts "   🌐 Total schools with websites: #{schools_with_websites}"
      puts "   📄 Schools with crawl data: #{total_crawled}"
      puts "   ✅ Successful crawls: #{successful_crawls}"
      puts "   📊 Average pages per school: #{School.where.not(website_pages_found: nil).average(:website_pages_found)&.round(1)}"

      # Error summary
      if @stats[:errors].any?
        puts "\n❌ Error Summary (first 5):"
        @stats[:errors].first(5).each do |error|
          puts "   • #{error}"
        end

        if @stats[:errors].count > 5
          puts "   ... and #{@stats[:errors].count - 5} more errors"
        end
      end

      puts "🎉" * 25
    end

    def should_skip_school?(school)
      # Skip if recently crawled and successful
      if school.website_crawled_at&.> MAX_CRAWL_AGE_DAYS.days.ago
        if school.website_crawling_status == "completed"
          days_old = ((Time.current - school.website_crawled_at) / 1.day).round(1)
          puts "⏭️  Skipped: #{school.name&.truncate(40)} (crawled #{days_old} days ago)"
          @stats[:skipped] += 1
          return true
        end
      end

      # Skip if website URL is invalid
      website_url = get_website_url(school)
      unless website_url&.match?(URI::DEFAULT_PARSER.make_regexp([ "http", "https" ]))
        puts "⚠️  Skipped: #{school.name&.truncate(40)} (invalid URL: #{website_url})"
        @stats[:skipped] += 1
        return true
      end

      false
    end

    # Main processing method
    def process_all_schools
      validate_environment

      schools = get_schools_to_crawl
      return if schools.empty?

      @stats[:total_schools] = schools.count

      if DRY_RUN
        puts "🧪 DRY RUN MODE - No database changes will be made"
      end

      puts "\n🚀 Starting website crawling for #{@stats[:total_schools]} schools"
      puts "⚙️  Configuration:"
      puts "   📦 Batch size: #{BATCH_SIZE} schools"
      puts "   ⏱️  Delay between crawls: #{DELAY_BETWEEN_CRAWLS} seconds"
      puts "   📅 Max crawl age: #{MAX_CRAWL_AGE_DAYS} days"
      puts "   🐍 Python script: #{File.basename(PYTHON_SCRIPT)}"

      puts "\n🚦 Starting in 3 seconds..."
      sleep 3

      # Process in batches
      batch_index = 0
      total_batches = (schools.count.to_f / BATCH_SIZE).ceil

      schools.in_batches(of: BATCH_SIZE) do |batch|
        batch_index += 1
        puts "\n📦 Processing batch #{batch_index}/#{total_batches}"
        puts "-" * 60

        batch.each do |school|
          @stats[:processed] += 1

          # Skip if not needed
          next if should_skip_school?(school)

          # Crawl the school website
          crawl_school_website(school)

          # Delay between crawls to respect rate limits
          if @stats[:processed] < @stats[:total_schools]
            puts "   😴 Sleeping #{DELAY_BETWEEN_CRAWLS}s..."
            sleep DELAY_BETWEEN_CRAWLS
          end
        end

        # Progress report after each batch
        print_progress_report

        # Longer delay between batches
        unless batch_index == total_batches
          batch_delay = DELAY_BETWEEN_CRAWLS * 2
          puts "💤 Batch complete, sleeping #{batch_delay}s before next batch...\n"
          sleep batch_delay
        end
      end

      print_final_summary
    end

    # Execute the main processing
    puts "🌐 School Website Crawler - Firecrawl Edition"
    puts "=" * 50

    begin
      process_all_schools
    rescue Interrupt
      puts "\n⛔ Process interrupted by user"
      print_final_summary
    rescue => e
      puts "\n💥 Unexpected error: #{e.message}"
      puts e.backtrace.first(5)
      print_final_summary
    end
  end
end
