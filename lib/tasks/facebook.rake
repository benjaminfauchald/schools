namespace :facebook do
  desc "Debug Facebook API connection and credentials"
  task debug: :environment do
    puts "🔍 Facebook API Debug Mode"
    puts "="*50

    # Check environment variables
    puts "Environment Variables:"
    puts "  FACEBOOK_APP_ID: #{ENV['FACEBOOK_APP_ID'] ? "✓ Set (#{ENV['FACEBOOK_APP_ID']})" : "✗ Missing"}"
    puts "  FACEBOOK_APP_SECRET: #{ENV['FACEBOOK_APP_SECRET'] ? "✓ Set (#{ENV['FACEBOOK_APP_SECRET'][0..10]}...)" : "✗ Missing"}"
    puts "  FACEBOOK_ACCESS_TOKEN: #{ENV['FACEBOOK_ACCESS_TOKEN'] ? "✓ Set (#{ENV['FACEBOOK_ACCESS_TOKEN'][0..20]}...)" : "✗ Missing"}"
    puts ""

    begin
      # Initialize service in debug mode
      service = FacebookExtractorService.new(debug: true)
      puts "\n✅ Service initialized successfully"
    rescue => e
      puts "\n❌ Service initialization failed: #{e.message}"
      exit 1
    end
  end

  desc "Extract Facebook data (including images) for all schools"
  task extract_all: :environment do
    # Verify credentials exist
    unless ENV["FACEBOOK_APP_ID"] && ENV["FACEBOOK_APP_SECRET"] && ENV["FACEBOOK_ACCESS_TOKEN"]
      puts "ERROR: Missing Facebook credentials in environment variables"
      puts "Required: FACEBOOK_APP_ID, FACEBOOK_APP_SECRET, FACEBOOK_ACCESS_TOKEN"
      exit 1
    end

    FacebookExtractorService.new.extract_all_schools
  end

  desc "Extract Facebook data for a specific school by ID"
  task :extract_one, [ :school_id ] => :environment do |t, args|
    unless args[:school_id]
      puts "ERROR: Please provide a school ID"
      puts "Usage: rails facebook:extract_one[123]"
      puts "Usage with debug: rails facebook:extract_one[123] DEBUG=true"
      exit 1
    end

    school = School.find(args[:school_id])
    puts "Extracting Facebook data for: #{school.name}"
    puts "Facebook URL: #{school.facebook_url}"

    debug_mode = ENV["DEBUG"] == "true"
    service = FacebookExtractorService.new(debug: debug_mode)
    service.extract_school_data(school)
  end

  desc "Test basic Facebook page access (minimal permissions)"
  task :test_basic, [ :facebook_url ] => :environment do |t, args|
    unless args[:facebook_url]
      puts "ERROR: Please provide a Facebook URL"
      puts "Usage: rails facebook:test_basic['https://www.facebook.com/YourSchoolPage']"
      exit 1
    end

    service = FacebookExtractorService.new(debug: true)
    page_id = service.send(:extract_page_id_from_url, args[:facebook_url])

    puts "Facebook URL: #{args[:facebook_url]}"
    puts "Extracted Page ID: #{page_id}"

    if page_id
      result = service.send(:test_basic_access, page_id)
      if result
        puts "\n✅ SUCCESS! Basic page access works"
        puts "Page ID: #{result['id']}"
        puts "Page Name: #{result['name']}" if result["name"]
      else
        puts "\n❌ Basic page access failed"
      end
    else
      puts "ERROR: Could not extract page ID from URL"
    end
  end

  desc "Test Facebook extraction with a sample URL"
  task :test, [ :facebook_url ] => :environment do |t, args|
    unless args[:facebook_url]
      puts "ERROR: Please provide a Facebook URL"
      puts "Usage: rails facebook:test['https://www.facebook.com/YourSchoolPage']"
      exit 1
    end

    # Create temporary school object for testing
    school = School.new(
      id: 0,
      name: "Test School",
      facebook_url: args[:facebook_url]
    )

    service = FacebookExtractorService.new(debug: true)
    page_id = service.send(:extract_page_id_from_url, args[:facebook_url])

    puts "Facebook URL: #{args[:facebook_url]}"
    puts "Extracted Page ID: #{page_id}"

    if page_id
      begin
        data = service.send(:fetch_page_data, page_id)
        profile_pic = service.send(:extract_profile_picture_url, data)
        cover_photo = service.send(:extract_cover_photo_url, data)

        puts "Page Name: #{data['name']}"
        puts "Profile Picture URL: #{profile_pic}"
        puts "Cover Photo URL: #{cover_photo}"
        puts "Fan Count: #{data['fan_count']}"
        puts "Verified: #{data['is_verified']}"

        puts "\nSuccess! Page data can be extracted."
      rescue => e
        puts "ERROR: #{e.message}"
      end
    else
      puts "ERROR: Could not extract page ID from URL"
    end
  end

  desc "Show statistics on Facebook data coverage"
  task stats: :environment do
    total = School.count
    with_fb_url = School.where.not(facebook_url: [ nil, "" ]).count
    with_data = School.where.not(facebook_content: nil).count
    with_images = School.where.not(facebook_profile_picture_url: nil).count

    puts "\nFacebook Data Coverage Report"
    puts "="*40
    puts "Total schools: #{total}"
    puts "Schools with Facebook URL: #{with_fb_url} (#{(with_fb_url.to_f/total*100).round(2)}%)"
    puts "Schools with extracted data: #{with_data} (#{(with_data.to_f/total*100).round(2)}%)"
    puts "Schools with profile pictures: #{with_images} (#{(with_images.to_f/total*100).round(2)}%)"

    # Show sample
    if school = School.where.not(facebook_content: nil).first
      puts "\nSample school with data: #{school.name}"
      puts "Profile Picture: #{school.facebook_profile_picture_url}"
      puts "Cover Photo: #{school.facebook_cover_photo_url}"
      puts "Data age: #{school.facebook_data_age_in_days&.round(1)} days"
    end

    # Schools that need refresh
    schools_with_fb_urls = School.where.not(facebook_url: [ nil, "" ])
    needs_refresh = schools_with_fb_urls.select { |s| s.facebook_last_fetched.nil? || s.facebook_data_age_in_days.to_i > 30 }.count
    puts "Schools needing refresh (>30 days or no data): #{needs_refresh}"
  end

  desc "Extract Facebook data for schools that need refresh"
  task extract_stale: :environment do
    schools_with_fb_urls = School.where.not(facebook_url: [ nil, "" ])
    schools_needing_refresh = schools_with_fb_urls.select(&:needs_facebook_refresh?)

    puts "Found #{schools_needing_refresh.count} schools needing Facebook data refresh"

    if schools_needing_refresh.any?
      service = FacebookExtractorService.new
      schools_needing_refresh.each_with_index do |school, index|
        puts "Processing #{index + 1}/#{schools_needing_refresh.count}: #{school.name}"
        service.extract_school_data(school)
        sleep(0.5) # Rate limiting
      end
      service.send(:print_report)
    else
      puts "All schools with Facebook URLs have fresh data!"
    end
  end
end
