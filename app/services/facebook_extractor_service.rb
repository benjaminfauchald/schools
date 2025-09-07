class FacebookExtractorService
  PROFILE_PICTURE_SIZES = [ "large", "normal", "small" ]
  API_FIELDS = %w[
    id name about description mission company_overview
    location address phone website emails hours
    category category_list fan_count talking_about_count
    cover picture.type(large) photos{images,name}
    founded general_info parking price_range
    verification_status is_verified
  ].join(",")

  # Simplified API fields for testing with limited permissions
  API_FIELDS_BASIC = %w[
    id name
  ].join(",")

  def initialize(debug: false)
    @debug = debug

    # Validate environment variables
    validate_credentials!

    # Configure Koala with app credentials
    Koala.config.app_id = ENV["FACEBOOK_APP_ID"]
    Koala.config.app_secret = ENV["FACEBOOK_APP_SECRET"]

    debug_log "Koala configured with App ID: #{ENV['FACEBOOK_APP_ID']}"
    debug_log "Access token (first 20 chars): #{ENV['FACEBOOK_ACCESS_TOKEN'][0..19]}..."

    @graph = Koala::Facebook::API.new(ENV["FACEBOOK_ACCESS_TOKEN"])
    @errors = []
    @stats = { processed: 0, success: 0, failed: 0, skipped: 0 }

    # Test the connection
    test_api_connection if @debug
  end

  def extract_all_schools
    puts "Starting Facebook extraction for all schools..."

    School.find_each.with_index do |school, index|
      puts "Processing #{index + 1}: #{school.name}"
      extract_school_data(school)

      # Rate limiting: 2 requests per second max
      sleep(0.5)
    end

    print_report
  end

  def extract_school_data(school)
    @stats[:processed] += 1

    # Skip if no Facebook URL
    unless school.facebook_url.present?
      @stats[:skipped] += 1
      return
    end

    # Extract page ID from URL
    page_id = extract_page_id_from_url(school.facebook_url)
    unless page_id
      log_error(school, "Could not extract page ID from URL: #{school.facebook_url}")
      @stats[:failed] += 1
      return
    end

    begin
      # Fetch all page data
      page_data = fetch_page_data(page_id)

      # Extract image URLs with highest quality
      profile_picture_url = extract_profile_picture_url(page_data)
      cover_photo_url = extract_cover_photo_url(page_data)

      # Download images if enabled (optional)
      if should_download_images?
        download_and_store_images(school, profile_picture_url, cover_photo_url)
      end

      # Structure and save all data
      structured_data = structure_facebook_data(page_data, profile_picture_url, cover_photo_url)

      school.update!(
        facebook_content: structured_data,
        facebook_last_fetched: Time.current,
        facebook_profile_picture_url: profile_picture_url,
        facebook_cover_photo_url: cover_photo_url
      )

      @stats[:success] += 1
      puts "✓ Successfully extracted data for #{school.name}"

    rescue Koala::Facebook::APIError => e
      handle_api_error(school, e)
    rescue => e
      handle_general_error(school, e)
    end
  end

  private

  def fetch_page_data(page_id)
    # Main API call to get all page data
    @graph.get_object(page_id, fields: API_FIELDS)
  end

  def extract_profile_picture_url(page_data)
    # Facebook provides different image sizes
    # Get the highest resolution available
    if page_data["picture"] && page_data["picture"]["data"]
      picture_data = page_data["picture"]["data"]

      # Try to get higher resolution
      if picture_data["url"]
        # Modify URL to get larger size
        url = picture_data["url"]
        url.gsub!(/width=\d+/, "width=800")
        url.gsub!(/height=\d+/, "height=800")
        url
      end
    end
  end

  def extract_cover_photo_url(page_data)
    # Extract cover photo URL
    if page_data["cover"] && page_data["cover"]["source"]
      page_data["cover"]["source"]
    end
  end

  def download_and_store_images(school, profile_url, cover_url)
    # Optional: Download and store images locally
    # This is useful if Facebook URLs expire or you want local copies

    if profile_url
      download_image(profile_url, "schools/#{school.id}/facebook_profile.jpg")
    end

    if cover_url
      download_image(cover_url, "schools/#{school.id}/facebook_cover.jpg")
    end
  rescue => e
    Rails.logger.error "Image download failed for school #{school.id}: #{e.message}"
  end

  def download_image(url, path)
    # Using Down gem to safely download images
    Down.download(url, destination: Rails.root.join("public", "uploads", path))
  end

  def structure_facebook_data(page_data, profile_picture_url, cover_photo_url)
    {
      fetched_at: Time.current,
      page_id: page_data["id"],

      # Basic Information
      basic_info: {
        name: page_data["name"],
        about: page_data["about"],
        description: page_data["description"],
        mission: page_data["mission"],
        company_overview: page_data["company_overview"],
        founded: page_data["founded"],
        general_info: page_data["general_info"]
      },

      # Visual Assets - IMPORTANT FOR YOUR USE CASE
      visual_assets: {
        profile_picture: {
          url: profile_picture_url,
          original_data: page_data["picture"]
        },
        cover_photo: {
          url: cover_photo_url,
          original_data: page_data["cover"]
        },
        photo_count: page_data["photos"]&.size || 0,
        photos: extract_photo_urls(page_data["photos"])
      },

      # Contact Information
      contact_info: {
        location: page_data["location"],
        address: page_data["address"],
        phone: page_data["phone"],
        website: page_data["website"],
        emails: page_data["emails"]
      },

      # Business Details
      business_info: {
        hours: page_data["hours"],
        parking: page_data["parking"],
        price_range: page_data["price_range"],
        category: page_data["category"],
        category_list: page_data["category_list"]
      },

      # Engagement Metrics
      engagement: {
        fan_count: page_data["fan_count"],
        talking_about_count: page_data["talking_about_count"]
      },

      # Verification Status
      verification: {
        is_verified: page_data["is_verified"],
        verification_status: page_data["verification_status"]
      }
    }
  end

  def extract_photo_urls(photos_data)
    return [] unless photos_data

    photos_data.map do |photo|
      {
        url: photo.dig("images", 0, "source"),
        width: photo.dig("images", 0, "width"),
        height: photo.dig("images", 0, "height"),
        name: photo["name"]
      }
    end.first(10) # Limit to 10 photos
  end

  def extract_page_id_from_url(facebook_url)
    # Handle various Facebook URL formats:
    # - https://www.facebook.com/PageName
    # - https://www.facebook.com/pages/Page-Name/123456789
    # - https://www.facebook.com/profile.php?id=123456789
    # - https://m.facebook.com/PageName

    return nil unless facebook_url.present?

    # Clean URL
    url = facebook_url.strip.downcase

    case url
    when /facebook\.com\/pages\/[\w\-]+\/(\d+)/
      $1
    when /facebook\.com\/profile\.php\?id=(\d+)/
      $1
    when /facebook\.com\/([\w\.\-]+)\/?$/
      $1.split("?").first
    else
      # Last resort: extract last path segment
      url.split("/").last.split("?").first
    end
  end

  def should_download_images?
    # Configure whether to download images locally
    ENV["DOWNLOAD_FACEBOOK_IMAGES"] == "true"
  end

  def handle_api_error(school, error)
    @stats[:failed] += 1
    error_message = "Facebook API Error: #{error.message}"
    log_error(school, error_message)

    # Check for specific errors
    if error.message.include?("Invalid OAuth")
      puts "ERROR: Invalid Facebook access token. Please update your credentials."
    elsif error.message.include?("rate limit")
      puts "WARNING: Hit rate limit. Waiting 60 seconds..."
      sleep(60)
    end
  end

  def handle_general_error(school, error)
    @stats[:failed] += 1
    log_error(school, "Unexpected error: #{error.message}")
  end

  def log_error(school, message)
    error_entry = "School ##{school.id} (#{school.name}): #{message}"
    @errors << error_entry
    Rails.logger.error error_entry
  end

  def print_report
    puts "\n" + "="*60
    puts "Facebook Data Extraction Complete"
    puts "="*60
    puts "Total Processed: #{@stats[:processed]}"
    puts "Successful: #{@stats[:success]}"
    puts "Failed: #{@stats[:failed]}"
    puts "Skipped (no Facebook URL): #{@stats[:skipped]}"

    if @errors.any?
      puts "\nErrors encountered:"
      @errors.each { |error| puts "  - #{error}" }
    end
  end

  # Debug and validation methods
  def validate_credentials!
    missing = []
    missing << "FACEBOOK_APP_ID" unless ENV["FACEBOOK_APP_ID"].present?
    missing << "FACEBOOK_APP_SECRET" unless ENV["FACEBOOK_APP_SECRET"].present?
    missing << "FACEBOOK_ACCESS_TOKEN" unless ENV["FACEBOOK_ACCESS_TOKEN"].present?

    if missing.any?
      raise "Missing Facebook credentials: #{missing.join(', ')}"
    end

    debug_log "✓ All Facebook credentials present"
  end

  def test_api_connection
    debug_log "\n" + "="*50
    debug_log "FACEBOOK API CONNECTION TEST"
    debug_log "="*50

    # Test 1: Check token info
    begin
      debug_log "Test 1: Checking access token info..."
      token_info = @graph.debug_token(ENV["FACEBOOK_ACCESS_TOKEN"])
      debug_log "✓ Token info: #{token_info}"
    rescue => e
      debug_log "✗ Token info failed: #{e.message}"
    end

    # Test 2: Try to get basic app info
    begin
      debug_log "\nTest 2: Getting app info..."
      app_info = @graph.get_object(ENV["FACEBOOK_APP_ID"], fields: "id,name,link")
      debug_log "✓ App info: #{app_info}"
    rescue => e
      debug_log "✗ App info failed: #{e.message}"
    end

    # Test 3: Try a known public page
    begin
      debug_log "\nTest 3: Testing with Facebook's own page..."
      fb_page = @graph.get_object("facebook", fields: "id,name,fan_count")
      debug_log "✓ Public page access works: #{fb_page}"
    rescue => e
      debug_log "✗ Public page failed: #{e.message}"
    end

    # Test 4: Check permissions
    begin
      debug_log "\nTest 4: Checking token permissions..."
      permissions = @graph.get_connections("me", "permissions")
      debug_log "✓ Token permissions: #{permissions}"
    rescue => e
      debug_log "✗ Permissions check failed: #{e.message}"
    end

    # Test 5: Verify app access token
    begin
      debug_log "\nTest 5: Generating app access token..."
      app_token = @graph.get_app_access_token
      debug_log "✓ App access token: #{app_token[0..20]}..."

      # Try with app token
      app_graph = Koala::Facebook::API.new(app_token)
      app_info = app_graph.get_object(ENV["FACEBOOK_APP_ID"])
      debug_log "✓ App token works: #{app_info}"
    rescue => e
      debug_log "✗ App token failed: #{e.message}"
    end

    debug_log "="*50
  end

  def debug_log(message)
    puts message if @debug
  end

  # Test with minimal fields to check if page exists
  def test_basic_access(page_id)
    debug_log "\nTesting basic access to page: #{page_id}"

    begin
      # Try with minimal fields first
      basic_data = @graph.get_object(page_id, fields: API_FIELDS_BASIC)
      debug_log "✓ Basic access successful: #{basic_data}"
      basic_data
    rescue Koala::Facebook::APIError => e
      debug_log "✗ Basic access failed: #{e.message}"
      nil
    end
  end

  # Enhanced error handling with detailed debugging
  def fetch_page_data(page_id)
    debug_log "\nFetching data for page ID: #{page_id}"
    debug_log "Fields requested: #{API_FIELDS}"
    debug_log "Full URL: https://graph.facebook.com/v18.0/#{page_id}?fields=#{API_FIELDS}&access_token=..."

    begin
      data = @graph.get_object(page_id, fields: API_FIELDS)
      debug_log "✓ Successfully fetched #{data.keys.size} fields"
      debug_log "Available fields: #{data.keys.join(', ')}"
      data
    rescue Koala::Facebook::APIError => e
      debug_log "✗ Facebook API Error details:"
      debug_log "  Code: #{e.fb_error_code}"
      debug_log "  Type: #{e.fb_error_type}"
      debug_log "  Message: #{e.message}"
      debug_log "  Subcode: #{e.fb_error_subcode}" if e.fb_error_subcode
      debug_log "  User Title: #{e.fb_error_user_title}" if e.fb_error_user_title
      debug_log "  User Message: #{e.fb_error_user_msg}" if e.fb_error_user_msg
      debug_log "  Trace ID: #{e.fb_error_trace_id}" if e.fb_error_trace_id

      # Suggest solutions based on error code
      suggest_solution(e.fb_error_code)

      raise e
    end
  end

  def suggest_solution(error_code)
    case error_code
    when 200
      debug_log "💡 SOLUTION: Error 200 usually means invalid app credentials."
      debug_log "   Check that your FACEBOOK_APP_ID matches the app that generated the access token."
    when 100
      debug_log "💡 SOLUTION: Error 100 means invalid parameter or missing required field."
    when 104
      debug_log "💡 SOLUTION: Error 104 means access token required or invalid."
      debug_log "   Your token might be expired or lack required permissions."
    when 190
      debug_log "💡 SOLUTION: Error 190 means access token expired."
      debug_log "   Generate a new access token from Facebook Developer Console."
    when 210
      debug_log "💡 SOLUTION: Error 210 means user not visible or page not found."
      debug_log "   The page might be private or the ID incorrect."
    else
      debug_log "💡 Check Facebook's error documentation for error code #{error_code}"
    end
  end
end
