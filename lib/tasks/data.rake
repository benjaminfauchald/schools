# Data Management Rake Tasks
# Usage:
#   rails data:sync_schools_from_places        - Sync schools from Places (production)
#   rails data:sync_schools_dry_run           - Preview sync changes without committing
#   rails data:sync_schools_report            - Show current sync statistics
#   rails data:clean_old_school_data          - Remove outdated school records

namespace :data do
  desc "Sync School records from Google Places API data in Places model"
  task sync_schools_from_places: :environment do
    puts "🏫 Starting Schools sync from Places data..."
    puts "📅 Sync started at: #{Time.current}"
    puts ""
    
    syncer = SchoolPlacesSyncer.new(dry_run: false)
    result = syncer.sync!
    
    puts "\n✅ Schools sync completed!"
    puts "📊 Summary: #{result[:created]} created, #{result[:updated]} updated, #{result[:skipped]} skipped, #{result[:errors]} errors"
    puts "⏱️  Duration: #{result[:duration].round(2)} seconds"
  end
  
  desc "Preview School sync changes without committing (dry run)"
  task sync_schools_dry_run: :environment do
    puts "🔍 Dry run: Preview Schools sync from Places data..."
    puts "📅 Preview started at: #{Time.current}"
    puts ""
    
    syncer = SchoolPlacesSyncer.new(dry_run: true)
    result = syncer.sync!
    
    puts "\n✅ Dry run completed!"
    puts "📊 Would: #{result[:created]} create, #{result[:updated]} update, #{result[:skipped]} skip"
    puts "⚠️  #{result[:errors]} potential errors found"
    puts "⏱️  Duration: #{result[:duration].round(2)} seconds"
    puts "\n💡 Run 'rails data:sync_schools_from_places' to apply these changes"
  end
  
  desc "Monthly School sync optimized for recurring operations (cron-ready)"
  task sync_schools_monthly: :environment do
    puts "🏫 Starting Monthly Schools Sync..."
    puts "📅 Sync started at: #{Time.current}"
    puts ""
    
    # Create backup before sync
    puts "📦 Creating backup before sync..."
    begin
      Rake::Task['data:backup'].invoke
      puts "✅ Backup created successfully"
    rescue => e
      puts "⚠️  Backup failed: #{e.message}"
      puts "💡 Continuing without backup - consider manual backup"
    end
    
    # Initialize monthly syncer with optimizations
    syncer = SchoolPlacesSyncer.new(dry_run: false, monthly_mode: true)
    result = syncer.sync!
    
    # Generate monthly report
    puts "\n📊 Monthly Sync Summary:"
    puts "=" * 50
    puts "✅ Sync completed successfully!"
    puts "📈 Results: #{result[:created]} created, #{result[:updated]} updated, #{result[:skipped]} skipped"
    puts "❌ Errors: #{result[:errors]} errors encountered"
    puts "⏱️  Duration: #{result[:duration].round(2)} seconds"
    puts "🏫 Total active schools: #{School.published.count}"
    
    if result[:errors] > 0
      puts "\n⚠️  Errors detected - check log file: log/schools_sync.log"
      puts "💡 Run 'rails data:sync_schools_logs' to view detailed logs"
    end
    
    # Update last sync timestamp
    timestamp_file = Rails.root.join('tmp', 'last_monthly_sync.txt')
    File.write(timestamp_file, Time.current.iso8601)
    
    puts "\n🔄 Next monthly sync recommended: #{1.month.from_now.strftime('%Y-%m-%d')}"
    puts "💡 Add to cron: 0 2 1 * * cd #{Rails.root} && rails data:sync_schools_monthly"
  end

  desc "Show Schools sync statistics and data health report"
  task sync_schools_report: :environment do
    puts "📊 Schools Data Sync Report"
    puts "=" * 50
    puts ""
    
    # Basic counts
    total_places = Place.count
    school_places = Place.where("types::jsonb ? 'school' OR types::jsonb ? 'university'").count
    total_schools = School.count
    schools_with_places = School.joins(:place).count
    
    puts "📍 Places Overview:"
    puts "   Total Places: #{total_places}"
    puts "   School/University Places: #{school_places}"
    puts ""
    
    puts "🏫 Schools Overview:"
    puts "   Total Schools: #{total_schools}"
    puts "   Schools with Places: #{schools_with_places}"
    puts "   Schools without Places: #{total_schools - schools_with_places}"
    puts ""
    
    # Data freshness
    if total_places > 0
      recently_fetched = Place.where('last_fetched_at > ?', 30.days.ago).count
      needs_refresh = Place.where('last_fetched_at IS NULL OR last_fetched_at < ?', 30.days.ago).count
      
      puts "📅 Data Freshness (30-day window):"
      puts "   Recent data: #{recently_fetched} places"
      puts "   Needs refresh: #{needs_refresh} places"
      puts "   Freshness: #{((recently_fetched.to_f / total_places) * 100).round(1)}%"
      puts ""
    end
    
    # Sync recommendations
    if school_places > total_schools
      puts "💡 Recommendations:"
      puts "   • #{school_places - total_schools} school Places not yet synced to Schools"
      puts "   • Run 'rails data:sync_schools_from_places' to create missing Schools"
    elsif school_places < total_schools
      puts "⚠️  Data Issues:"
      puts "   • More Schools (#{total_schools}) than school Places (#{school_places})"
      puts "   • Some Schools may reference deleted Places"
      puts "   • Run 'rails data:clean_old_school_data' to clean up orphaned records"
    else
      puts "✅ Data Health: Schools and Places counts match"
    end
    
    puts ""
    puts "🔄 Last sync info:"
    last_sync_file = Rails.root.join('tmp', 'last_schools_sync.json')
    if File.exist?(last_sync_file)
      last_sync = JSON.parse(File.read(last_sync_file))
      puts "   Last run: #{last_sync['completed_at']}"
      puts "   Result: #{last_sync['summary']}"
    else
      puts "   No previous sync recorded"
    end
  end
  
  desc "Archive schools for permanently closed places"
  task archive_closed_schools: :environment do
    puts "🔒 Starting archive of closed schools..."
    
    # Find schools linked to permanently closed places
    closed_schools = School.joins(:place)
                          .where("places.business_status = 'CLOSED_PERMANENTLY' OR places.permanently_closed = true")
                          .where.not(status: 'suspended')
    
    if closed_schools.count == 0
      puts "✅ No schools need archiving - all closed places already handled"
      return
    end
    
    puts "🏫 Found #{closed_schools.count} schools linked to permanently closed places:"
    closed_schools.limit(5).each do |school|
      puts "   - #{school.name} (#{school.place.business_status})"
    end
    puts "   ... and #{closed_schools.count - 5} more" if closed_schools.count > 5
    
    # 🛡️ SAFETY CHECK: Follow CLAUDE.md protection rules
    puts "\n⚠️  WARNING: About to archive closed schools"
    puts "Action: Change status to 'suspended' for permanently closed places"
    puts "Records affected: #{closed_schools.count} schools"
    puts ""
    
    print "Continue? Type 'ARCHIVE CONFIRMED' to proceed: "
    confirmation = STDIN.gets.chomp
    unless confirmation == 'ARCHIVE CONFIRMED'
      puts "❌ Operation cancelled - schools preserved"
      return
    end
    
    # Archive the schools
    archived_count = 0
    closed_schools.find_each do |school|
      begin
        school.update!(
          status: 'suspended',
          last_verification_at: Time.current
        )
        archived_count += 1
        puts "🔒 Archived: #{school.name}"
      rescue => e
        puts "❌ Failed to archive #{school.name}: #{e.message}"
      end
    end
    
    puts "\n✅ Archived #{archived_count} schools for permanently closed places"
    puts "💡 These schools can be restored if places reopen"
  end

  desc "Clean up outdated School records and orphaned data"
  task clean_old_school_data: :environment do
    puts "🧹 Cleaning outdated School data..."
    
    # Find schools without places
    orphaned_schools = School.left_joins(:place).where(places: { id: nil })
    puts "🗑️  Found #{orphaned_schools.count} schools without Places"
    
    if orphaned_schools.count > 0
      # 🛡️ SAFETY CHECK: Follow CLAUDE.md protection rules
      puts "⚠️  WARNING: About to delete orphaned school data"
      puts "Records to delete: #{orphaned_schools.count}"
      puts "Sample records:"
      orphaned_schools.limit(3).each { |s| puts "  - #{s.name || s.id}" }
      puts ""
      
      print "Continue? Type 'DELETE CONFIRMED' to proceed: "
      confirmation = STDIN.gets.chomp
      if confirmation == 'DELETE CONFIRMED'
        count = orphaned_schools.count
        orphaned_schools.destroy_all
        puts "✅ Deleted #{count} orphaned schools"
      else
        puts "❌ Operation cancelled - orphaned schools preserved"
      end
    end
    
    # Find places that are no longer schools but have school records
    non_school_places_with_schools = School.joins(:place)
                                           .where.not("places.types::jsonb ? 'school' OR places.types::jsonb ? 'university'")
    
    puts "⚠️  Found #{non_school_places_with_schools.count} schools linked to non-school places"
    
    if non_school_places_with_schools.count > 0
      print "Archive schools for places that are no longer schools? [y/N]: "
      if STDIN.gets.chomp.downcase == 'y'
        non_school_places_with_schools.update_all(status: 'suspended')
        puts "✅ Suspended #{non_school_places_with_schools.count} schools for non-school places"
      else
        puts "⏭️  Skipped suspension"
      end
    end
    
    puts "🧹 Cleanup completed!"
  end
  
  desc "Show detailed sync logs from last operation"
  task sync_schools_logs: :environment do
    log_file = Rails.root.join('log', 'schools_sync.log')
    
    if File.exist?(log_file)
      puts "📋 Schools Sync Logs (last 50 lines):"
      puts "=" * 50
      puts File.readlines(log_file).last(50).join
    else
      puts "📋 No sync logs found"
      puts "💡 Run a sync operation first to generate logs"
    end
  end
end

# School Places Syncer Service Class
class SchoolPlacesSyncer
  attr_reader :dry_run, :monthly_mode
  
  def initialize(dry_run: false, monthly_mode: false)
    @dry_run = dry_run
    @monthly_mode = monthly_mode
    @stats = { 
      created: 0, updated: 0, skipped: 0, errors: 0, 
      archived: 0, data_quality_issues: 0, stale_places: 0
    }
    @start_time = Time.current
    @log_entries = []
    setup_logging
  end
  
  def sync!
    log("Starting Schools sync from Places data", :info)
    log("Mode: #{dry_run? ? 'DRY RUN' : 'PRODUCTION'}", :info)
    
    school_places = find_school_places
    log("Found #{school_places.count} school/university places to process", :info)
    
    school_places.find_each.with_index do |place, index|
      begin
        if index % 10 == 0
          puts "📍 Processing place #{index + 1}/#{school_places.count}..."
        end
        
        process_place(place)
        
      rescue => e
        @stats[:errors] += 1
        log("ERROR processing Place #{place.id}: #{e.message}", :error)
        puts "❌ Error processing Place #{place.id}: #{e.message}"
      end
    end
    
    duration = Time.current - @start_time
    
    # Save sync results
    save_sync_results(duration) unless dry_run?
    
    log("Sync completed in #{duration.round(2)} seconds", :info)
    log("Results: #{@stats}", :info)
    
    @stats.merge(duration: duration)
  end
  
  private
  
  def dry_run?
    @dry_run
  end
  
  def find_school_places
    base_scope = Place.successful_fetches
                      .where("types::jsonb ? 'school' OR types::jsonb ? 'university'")
                      .where.not(lat: nil, lng: nil)
                      .where.not(name: [nil, ''])
    
    if monthly_mode
      # In monthly mode, prioritize recently updated places and places that haven't been synced
      recently_updated = base_scope.where('last_fetched_at > ?', 7.days.ago)
      never_synced = base_scope.left_joins(:school).where(schools: { id: nil })
      
      # Track stale places for reporting
      @stats[:stale_places] = base_scope.where('last_fetched_at < ?', 30.days.ago).count
      
      # Combine recent updates and never synced, avoid duplicates
      place_ids = (recently_updated.pluck(:id) + never_synced.pluck(:id)).uniq
      base_scope.where(id: place_ids)
    else
      # Regular mode - process all school places
      base_scope
    end
  end
  
  def process_place(place)
    existing_school = find_existing_school(place)
    
    if existing_school
      update_school_from_place(existing_school, place)
    else
      create_school_from_place(place)
    end
  end
  
  def find_existing_school(place)
    # Look for existing school by place association first (most accurate)
    existing = School.find_by(place: place)
    return existing if existing
    
    # Look for school linked to a place with same place_id
    if place.place_id.present?
      existing = School.joins(:place).find_by(places: { place_id: place.place_id })
      return existing if existing
    end
    
    # Look for school linked to a place with same google_place_id (only if present)
    if place.google_place_id.present?
      existing = School.joins(:place).find_by(places: { google_place_id: place.google_place_id })
      return existing if existing
    end
    
    # No existing school found
    nil
  end
  
  def create_school_from_place(place)
    school_data = extract_school_data_from_place(place)
    
    # Validate data before creation
    validation_errors = validate_school_data(school_data, place)
    if validation_errors.any?
      @stats[:errors] += 1
      error_msg = "Validation failed for place #{place.place_id}: #{validation_errors.join(', ')}"
      log(error_msg, :error)
      puts "❌ #{school_data[:name]}: #{validation_errors.first}"
      return
    end
    
    if dry_run?
      log("Would CREATE school: #{school_data[:name]} (#{place.place_id})", :info)
      puts "➕ Would create: #{school_data[:name]}"
      @stats[:created] += 1
      return
    end
    
    begin
      school = School.create!(school_data)
      @stats[:created] += 1
      
      log("CREATED school #{school.id}: #{school.name} (#{place.place_id})", :info)
      puts "➕ Created: #{school.name}"
    rescue ActiveRecord::RecordInvalid => e
      @stats[:errors] += 1
      error_msg = "Failed to create school for place #{place.place_id}: #{e.message}"
      log(error_msg, :error)
      puts "❌ Create failed: #{school_data[:name]} - #{e.message}"
    end
  end
  
  def update_school_from_place(school, place)
    school_data = extract_school_data_from_place(place)
    
    # Validate data before update
    validation_errors = validate_school_data(school_data, place)
    if validation_errors.any?
      @stats[:errors] += 1
      error_msg = "Validation failed for school #{school.id} (place #{place.place_id}): #{validation_errors.join(', ')}"
      log(error_msg, :error)
      puts "❌ #{school.name}: #{validation_errors.first}"
      return
    end
    
    # Check what needs updating with conflict resolution
    needs_update = false
    changes = {}
    school_data_clean = school_data.except(:slug, :place) # Don't update slug or place association
    
    school_data_clean.each do |key, new_value|
      current_value = school.send(key)
      
      # Apply conflict resolution rules
      resolved_value = resolve_data_conflict(key, current_value, new_value, school, place)
      
      if current_value != resolved_value
        needs_update = true
        changes[key] = { 
          from: current_value, 
          to: resolved_value,
          source: resolved_value == new_value ? 'place' : 'preserved'
        }
        school_data_clean[key] = resolved_value
      end
    end
    
    if needs_update
      if dry_run?
        change_summary = changes.keys.join(', ')
        log("Would UPDATE school #{school.id}: #{change_summary}", :info)
        puts "🔄 Would update: #{school.name} (#{change_summary})"
        @stats[:updated] += 1
        return
      end
      
      begin
        school.update!(school_data_clean)
        @stats[:updated] += 1
        
        change_summary = changes.keys.join(', ')
        log("UPDATED school #{school.id}: #{change_summary}", :info)
        puts "🔄 Updated: #{school.name} (#{change_summary})"
        
        # Log detailed changes for important fields
        if changes.any? { |k, _| [:status, :ownership, :name].include?(k) }
          changes.each do |field, change|
            log("  #{field}: '#{change[:from]}' → '#{change[:to]}' (#{change[:source]})", :info)
          end
        end
        
      rescue ActiveRecord::RecordInvalid => e
        @stats[:errors] += 1
        error_msg = "Failed to update school #{school.id} (place #{place.place_id}): #{e.message}"
        log(error_msg, :error)
        puts "❌ Update failed: #{school.name} - #{e.message}"
      end
    else
      @stats[:skipped] += 1
      log("SKIPPED school #{school.id}: no changes needed", :debug) if school.id % 50 == 0
    end
  end
  
  def resolve_data_conflict(field, current_value, new_value, school, place)
    # Return new value if current is blank
    return new_value if current_value.blank?
    return current_value if new_value.blank?
    
    # Handle specific field conflicts
    case field
    when :name
      # Prefer more complete names, but don't override manually entered names
      if school.last_verification_at && school.last_verification_at > 30.days.ago
        # Recently manually verified - prefer current
        return current_value if new_value.length <= current_value.length
      end
      # Use the name with more information
      return new_value.length > current_value.length ? new_value : current_value
      
    when :phone
      # Prefer formatted phone numbers
      return new_value if new_value.include?('(') || new_value.include?('+')
      return current_value if current_value.include?('(') || current_value.include?('+')
      return new_value # Default to new
      
    when :email
      # Prefer manually entered emails over extracted ones
      return current_value if !current_value.include?('noreply') && new_value.include?('noreply')
      return new_value
      
    when :status
      # Preserve manual status changes unless place is permanently closed
      if place.business_status == 'CLOSED_PERMANENTLY' || place.permanently_closed
        return 'suspended'
      end
      # Don't downgrade published schools to pending_review without reason
      return current_value if current_value == 'published' && new_value == 'pending_review'
      return new_value
      
    when :ownership
      # Preserve manually set ownership unless we have high confidence in new value
      return current_value if current_value != 'other' && new_value == 'other'
      return new_value
      
    else
      # Default: use new value from place
      return new_value
    end
  end
  
  def extract_school_data_from_place(place)
    {
      # Core associations - maintain link to Place (Point accessible via place.point)
      place: place,
      
      # Basic Information
      name: place.name,
      slug: generate_unique_slug(place.name),
      about: extract_about_from_place(place),
      
      # Contact Information
      phone: extract_primary_phone_from_place(place),
      email: extract_email_from_place(place),
      website_url: place.website,
      
      # Address Components
      address_line_1: extract_address_line_1_from_place(place),
      address_line_2: extract_address_line_2_from_place(place),
      district: extract_district_from_place(place),
      province: extract_province_from_place(place),
      postcode: extract_postcode_from_place(place),
      country_code: extract_country_code_from_place(place),
      
      # Coordinates
      lat: place.lat,
      lng: place.lng,
      
      # Business Information
      status: determine_school_status_from_place(place),
      ownership: determine_ownership_from_place(place),
      founded_year: extract_founded_year_from_place(place),
      
      # Verification & Metadata
      last_verification_at: place.last_fetched_at
    }
  end
  
  def generate_unique_slug(name)
    base_slug = name.parameterize
    counter = 1
    candidate_slug = base_slug
    
    while School.exists?(slug: candidate_slug)
      candidate_slug = "#{base_slug}-#{counter}"
      counter += 1
    end
    
    candidate_slug
  end
  
  def extract_about_from_place(place)
    place.editorial_summary ||
    "#{place.name} is located in #{place.vicinity || place.formatted_address}." +
    (place.rating ? " Rated #{place.rating}/5 by #{place.user_ratings_total} reviews." : "")
  end
  
  def extract_primary_phone_from_place(place)
    # Prefer formatted phone number, fallback to international
    place.formatted_phone_number.presence || 
    place.international_phone_number.presence
  end
  
  def extract_email_from_place(place)
    # Try to extract from structured data first, then from website crawl
    email = place.website_structured_data&.dig('contact', 'email')
    email ||= place.website_structured_data&.dig('contactPoint', 'email') 
    email ||= place.website_crawl_data&.dig('contact', 'email')
    email&.strip&.downcase if email.present? && email.include?('@')
  end
  
  def extract_address_line_1_from_place(place)
    return nil unless place.address_components
    
    street_component = place.address_components.find { |c| c['types'].include?('route') }
    street_number = place.address_components.find { |c| c['types'].include?('street_number') }
    
    address_line_1 = [street_number&.dig('long_name'), street_component&.dig('long_name')].compact.join(' ')
    address_line_1.present? ? address_line_1 : nil
  end
  
  def extract_address_line_2_from_place(place)
    return nil unless place.address_components
    
    # Look for sublocality or premise information for address line 2
    sublocality = place.address_components.find { |c| c['types'].include?('sublocality') }
    premise = place.address_components.find { |c| c['types'].include?('premise') }
    establishment = place.address_components.find { |c| c['types'].include?('establishment') }
    
    line_2_components = [
      premise&.dig('long_name'),
      sublocality&.dig('long_name'),
      establishment&.dig('long_name')
    ].compact.uniq
    
    line_2_components.any? ? line_2_components.join(', ') : nil
  end
  
  def extract_founded_year_from_place(place)
    # Try to extract founding year from structured data or editorial summary
    founded_info = place.website_structured_data&.dig('foundingDate') ||
                   place.website_structured_data&.dig('dateCreated') ||
                   place.editorial_summary
    
    if founded_info.present?
      # Extract 4-digit year from various formats
      year_match = founded_info.to_s.match(/\b(19|20)\d{2}\b/)
      return year_match[0].to_i if year_match
    end
    
    nil
  end
  
  def extract_district_from_place(place)
    return nil unless place.address_components
    
    district_component = place.address_components.find do |c| 
      c['types'].include?('sublocality_level_1') || 
      c['types'].include?('administrative_area_level_2') ||
      c['types'].include?('locality')
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
  
  def extract_country_code_from_place(place)
    return nil unless place.address_components
    
    country_component = place.address_components.find { |c| c['types'].include?('country') }
    country_code = country_component&.dig('short_name')
    
    # Map to supported country codes
    case country_code
    when 'TH', 'US', 'GB', 'SG', 'MY', 'JP', 'KR', 'CN'
      country_code
    else
      nil
    end
  end
  
  def determine_school_status_from_place(place)
    # Handle permanently closed schools
    if place.business_status == 'CLOSED_PERMANENTLY' || place.permanently_closed
      return 'suspended'
    end
    
    # Handle operational schools
    if place.business_status == 'OPERATIONAL'
      # Additional checks for data quality before publishing
      return 'published' if has_sufficient_data_for_publication?(place)
      return 'pending_review'
    end
    
    # Handle temporarily closed or unknown status
    if place.business_status == 'CLOSED_TEMPORARILY'
      return 'pending_review'
    end
    
    # Default to pending review for unknown status
    'pending_review'
  end
  
  def has_sufficient_data_for_publication?(place)
    # Check if place has minimum required data for publication
    required_fields = [
      place.name,
      place.lat,
      place.lng,
      place.formatted_address
    ]
    
    # All required fields must be present
    return false unless required_fields.all?(&:present?)
    
    # At least one contact method should be available
    has_contact = place.formatted_phone_number.present? || 
                 place.website.present? || 
                 extract_email_from_place(place).present?
    
    # Place should not be flagged with API errors
    api_ok = place.api_status == 'OK' || place.api_status.nil?
    
    has_contact && api_ok
  end
  
  def determine_ownership_from_place(place)
    # Analyze place name and types to determine ownership
    name_lower = place.name.downcase
    types = place.types || []
    
    # Check for private school indicators
    private_indicators = [
      'international', 'private', 'preparatory', 'prep', 'academy',
      'bilingual', 'montessori', 'steiner', 'waldorf'
    ]
    return 'private' if private_indicators.any? { |indicator| name_lower.include?(indicator) }
    
    # Check for public/government school indicators
    public_indicators = [
      'public', 'government', 'state', 'municipal', 'national',
      'โรงเรียนรัฐ', 'โรงเรียนเทศบาล', 'วิทยาลัย', 'มหาวิทยาลัย'
    ]
    return 'nonprofit' if public_indicators.any? { |indicator| name_lower.include?(indicator) }
    
    # Check for foundation/religious indicators
    foundation_indicators = [
      'foundation', 'catholic', 'christian', 'buddhist', 'islamic',
      'temple', 'church', 'mosque', 'wat ', 'มูลนิธิ'
    ]
    return 'foundation' if foundation_indicators.any? { |indicator| name_lower.include?(indicator) }
    
    # Check structured data for organization type
    if place.website_structured_data.present?
      org_type = place.website_structured_data.dig('organizationType') ||
                 place.website_structured_data.dig('@type')
      return 'nonprofit' if org_type&.downcase&.include?('educational')
    end
    
    # Default to other if can't determine
    'other'
  end
  
  def validate_school_data(school_data, place)
    errors = []
    
    # Required field validation
    required_fields = [:name, :lat, :lng, :place]
    required_fields.each do |field|
      if school_data[field].blank?
        errors << "Missing required field: #{field}"
      end
    end
    
    # Coordinate validation
    if school_data[:lat].present? && !school_data[:lat].between?(-90, 90)
      errors << "Invalid latitude: #{school_data[:lat]}"
    end
    
    if school_data[:lng].present? && !school_data[:lng].between?(-180, 180)
      errors << "Invalid longitude: #{school_data[:lng]}"
    end
    
    # Email validation
    if school_data[:email].present?
      unless school_data[:email].match(URI::MailTo::EMAIL_REGEXP)
        errors << "Invalid email format: #{school_data[:email]}"
      end
    end
    
    # URL validation
    if school_data[:website_url].present?
      begin
        uri = URI.parse(school_data[:website_url])
        unless uri.scheme && uri.host
          errors << "Invalid website URL: #{school_data[:website_url]}"
        end
      rescue URI::InvalidURIError
        errors << "Malformed website URL: #{school_data[:website_url]}"
      end
    end
    
    # Founded year validation
    if school_data[:founded_year].present?
      current_year = Date.current.year
      unless school_data[:founded_year].between?(1800, current_year)
        errors << "Invalid founded year: #{school_data[:founded_year]}"
      end
    end
    
    errors
  end
  
  def setup_logging
    @logger = Logger.new(Rails.root.join('log', 'schools_sync.log'))
    @logger.level = Logger::INFO
  end
  
  def log(message, level = :info)
    timestamp = Time.current.strftime('%Y-%m-%d %H:%M:%S')
    formatted_message = "[#{timestamp}] #{message}"
    
    @log_entries << formatted_message
    @logger.send(level, formatted_message)
  end
  
  def save_sync_results(duration)
    results = {
      completed_at: Time.current.iso8601,
      duration_seconds: duration.round(2),
      mode: dry_run? ? 'dry_run' : 'production',
      sync_type: monthly_mode ? 'monthly' : 'full',
      stats: @stats,
      summary: generate_sync_summary,
      data_quality: generate_data_quality_report,
      performance: {
        records_per_second: (@stats.values.sum.to_f / duration).round(2),
        total_processed: @stats.values.sum,
        success_rate: calculate_success_rate
      },
      database_counts: {
        total_places: Place.count,
        school_places: Place.schools.count,
        total_schools: School.count,
        published_schools: School.published.count,
        suspended_schools: School.where(status: 'suspended').count
      }
    }
    
    # Save main sync results
    File.write(Rails.root.join('tmp', 'last_schools_sync.json'), results.to_json)
    
    # Save monthly-specific results if in monthly mode
    if monthly_mode
      monthly_results = results.merge({
        stale_places_count: @stats[:stale_places],
        next_recommended_sync: 1.month.from_now.iso8601,
        cron_schedule: "0 2 1 * *"
      })
      File.write(Rails.root.join('tmp', 'last_monthly_sync.json'), monthly_results.to_json)
    end
  end
  
  def generate_sync_summary
    base_summary = "#{@stats[:created]} created, #{@stats[:updated]} updated, #{@stats[:skipped]} skipped, #{@stats[:errors]} errors"
    
    if monthly_mode
      monthly_additions = []
      monthly_additions << "#{@stats[:archived]} archived" if @stats[:archived] > 0
      monthly_additions << "#{@stats[:stale_places]} stale places" if @stats[:stale_places] > 0
      
      if monthly_additions.any?
        base_summary + ", " + monthly_additions.join(", ")
      else
        base_summary
      end
    else
      base_summary
    end
  end
  
  def generate_data_quality_report
    {
      validation_errors: @stats[:errors],
      data_completeness: calculate_data_completeness,
      contact_info_coverage: calculate_contact_coverage,
      address_completeness: calculate_address_completeness
    }
  end
  
  def calculate_success_rate
    total_operations = @stats[:created] + @stats[:updated] + @stats[:errors]
    return 100.0 if total_operations == 0
    
    successful_operations = @stats[:created] + @stats[:updated]
    ((successful_operations.to_f / total_operations) * 100).round(1)
  end
  
  def calculate_data_completeness
    return 0 if School.count == 0
    
    complete_schools = School.joins(:place)
                            .where.not(phone: [nil, ''])
                            .where.not(places: { website: [nil, ''] })
                            .where.not(address_line_1: [nil, ''])
                            .count
                            
    ((complete_schools.to_f / School.count) * 100).round(1)
  end
  
  def calculate_contact_coverage
    return 0 if School.count == 0
    
    schools_with_contact = School.joins(:place)
                                .where(
                                  "schools.phone IS NOT NULL OR " +
                                  "schools.email IS NOT NULL OR " +
                                  "places.website IS NOT NULL"
                                ).count
                                
    ((schools_with_contact.to_f / School.count) * 100).round(1)
  end
  
  def calculate_address_completeness
    return 0 if School.count == 0
    
    schools_with_complete_address = School.where.not(
      address_line_1: [nil, ''],
      district: [nil, ''],
      province: [nil, '']
    ).count
    
    ((schools_with_complete_address.to_f / School.count) * 100).round(1)
  end
end

# ========================================
# TEST METADATA GENERATION TASKS
# ========================================

namespace :data do
  desc "Generate comprehensive test metadata for all existing schools"
  task generate_test_metadata: :environment do
    require 'faker'
    
    puts "🧪 Starting comprehensive test metadata generation..."
    puts "📅 Generation started at: #{Time.current}"
    puts ""
    
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    stats = { processed: 0, created: 0, errors: 0, skipped: 0 }
    
    # Preload all vocabularies and terms for efficiency
    puts "📚 Loading vocabularies and terms..."
    vocabs = {}
    Vocabulary.includes(:terms).each do |vocab|
      vocabs[vocab.code] = vocab.terms.active.to_a
    end
    
    total_schools = School.count
    puts "🏫 Processing #{total_schools} schools..."
    puts ""
    
    School.find_in_batches(batch_size: 25).with_index do |schools_batch, batch_index|
      puts "📍 Processing batch #{batch_index + 1} (schools #{batch_index * 25 + 1}-#{[total_schools, (batch_index + 1) * 25].min})..."
      
      schools_batch.each do |school|
        begin
          # Determine school tier and characteristics
          tier = determine_school_tier(school.name)
          school_type = determine_school_type(school.name)
          
          # Generate comprehensive metadata
          generate_school_taggings(school, vocabs, tier, school_type, timestamp)
          generate_fee_schedule(school, tier, timestamp)
          generate_grade_offering(school, tier, school_type, timestamp)
          generate_media_items(school, tier, timestamp)
          
          stats[:created] += 1
          stats[:processed] += 1
          
          # Show progress every 10 schools
          if stats[:processed] % 10 == 0
            puts "  ✅ Processed #{stats[:processed]}/#{total_schools} schools"
          end
          
        rescue => e
          stats[:errors] += 1
          stats[:processed] += 1
          puts "  ❌ Error processing #{school.name}: #{e.message}"
        end
      end
    end
    
    puts ""
    puts "✅ Test metadata generation completed!"
    puts "📊 Summary:"
    puts "   Processed: #{stats[:processed]} schools"
    puts "   Successfully generated: #{stats[:created]} complete profiles"
    puts "   Errors: #{stats[:errors]}"
    puts "   Duration: #{((Time.current - Time.parse("#{timestamp[0..7]} #{timestamp[9..10]}:#{timestamp[11..12]}:#{timestamp[13..14]}")) / 60).round(2)} minutes"
    puts ""
    
    # Show sample of generated data
    sample_school = School.joins(:taggings, :school_fee_schedules, :school_grade_offering).first
    if sample_school
      puts "📋 Sample Generated Profile: #{sample_school.name}"
      puts "   📚 Curriculum: #{sample_school.terms_by_context('curriculum').pluck(:label).join(', ')}"
      puts "   🏆 Accreditations: #{sample_school.terms_by_context('accreditation').pluck(:label).join(', ')}"
      puts "   🏊 Facilities: #{sample_school.terms_by_context('facility').count} facilities"
      puts "   💰 Fee Range: #{sample_school.current_fee_schedule&.tuition_range_display}"
      puts "   🎂 Age Range: #{sample_school.age_range}"
    end
  end
  
  desc "Clean all test-generated metadata (preserves original school records)"
  task clean_test_metadata: :environment do
    puts "🧹 Starting test metadata cleanup..."
    puts "📅 Cleanup started at: #{Time.current}"
    puts ""
    
    # Find all test-generated records
    test_taggings = Tagging.where("notes LIKE 'TEST_DATA_%'")
    test_fee_schedules = SchoolFeeSchedule.where("notes LIKE 'TEST_DATA_%'")  
    test_grade_offerings = SchoolGradeOffering.where("notes LIKE 'TEST_DATA_%'")
    test_media_items = MediaItem.where("alt_text LIKE 'TEST_DATA%'")
    
    total_records = test_taggings.count + test_fee_schedules.count + 
                   test_grade_offerings.count + test_media_items.count
    
    if total_records == 0
      puts "📭 No test metadata found to clean up."
      puts "💡 Run 'rails data:generate_test_metadata' first to create test data."
      next
    end
    
    puts "🔍 Found test metadata to remove:"
    puts "   📚 Taggings: #{test_taggings.count}"
    puts "   💰 Fee Schedules: #{test_fee_schedules.count}"
    puts "   🎂 Grade Offerings: #{test_grade_offerings.count}"
    puts "   📷 Media Items: #{test_media_items.count}"
    puts "   📊 Total Records: #{total_records}"
    puts ""
    
    # Safety check - show sample schools affected
    affected_schools = School.joins(:taggings).where(taggings: { notes: test_taggings.select(:notes).distinct.limit(5) })
    puts "📋 Sample schools that will lose test metadata:"
    affected_schools.limit(3).each { |s| puts "   - #{s.name}" }
    puts ""
    
    puts "⚠️  WARNING: This will permanently delete ALL test-generated metadata"
    puts "Original school records will be preserved, only attached metadata will be removed"
    puts ""
    
    print "Continue? Type 'CLEAN CONFIRMED' to proceed: "
    confirmation = STDIN.gets.chomp
    unless confirmation == 'CLEAN CONFIRMED'
      puts "❌ Operation cancelled - test metadata preserved"
      next
    end
    
    puts ""
    puts "🗑️  Removing test metadata..."
    
    ActiveRecord::Base.transaction do
      deleted_counts = {}
      
      deleted_counts[:taggings] = test_taggings.delete_all
      deleted_counts[:fee_schedules] = test_fee_schedules.delete_all
      deleted_counts[:grade_offerings] = test_grade_offerings.delete_all
      deleted_counts[:media_items] = test_media_items.delete_all
      
      puts "✅ Cleanup completed successfully!"
      puts "📊 Removed:"
      deleted_counts.each { |type, count| puts "   #{type.to_s.humanize}: #{count} records" }
      puts "   Total: #{deleted_counts.values.sum} records"
    end
    
    puts ""
    puts "🏫 Original school records preserved: #{School.count} schools"
  end
  
  desc "Regenerate test metadata (clean + generate)"
  task regenerate_test_metadata: :environment do
    puts "🔄 Regenerating all test metadata..."
    puts ""
    
    Rake::Task['data:clean_test_metadata'].invoke
    puts ""
    Rake::Task['data:generate_test_metadata'].invoke
  end
  
  # Helper methods for test metadata generation
  
  def determine_school_tier(name)
    name_lower = name.downcase
    
    # Premium international schools
    premium_keywords = %w[international british american australian singapore swiss german french 
                         ruamrudee harrow regents wellington shrewsbury nist bangkok prep]
    return :premium if premium_keywords.any? { |keyword| name_lower.include?(keyword) }
    
    # Standard schools (Christian, established local schools)
    standard_keywords = %w[christian catholic assumption st saint college academy prep school satri]
    return :standard if standard_keywords.any? { |keyword| name_lower.include?(keyword) }
    
    # Basic tier (local Thai schools)
    :basic
  end
  
  # Determine school type/focus
  def determine_school_type(name)
    name_lower = name.downcase
    
    return :international if name_lower.include?('international')
    return :british if name_lower.include?('british') || name_lower.include?('uk')
    return :american if name_lower.include?('american') || name_lower.include?('us')
    return :christian if name_lower.include?('christian') || name_lower.include?('catholic') || name_lower.include?('assumption')
    return :buddhist if name_lower.include?('wat ')
    return :thai_traditional if name_lower.match?(/โรงเรียน|วิทยา|ศึกษา/)
    
    :general
  end
  
  # Generate comprehensive taggings for a school
  def generate_school_taggings(school, vocabs, tier, school_type, timestamp)
    taggings_to_create = []
    
    # Generate curriculum taggings (2-5 programs)
    curriculum_terms = select_curriculum_terms(vocabs['curriculum'], tier, school_type)
    curriculum_terms.each do |term|
      taggings_to_create << build_tagging_attrs(school, term, 'curriculum', timestamp)
    end
    
    # Generate accreditation taggings (0-4 accreditations)  
    accreditation_terms = select_accreditation_terms(vocabs['accreditation'], tier)
    accreditation_terms.each do |term|
      taggings_to_create << build_tagging_attrs(school, term, 'accreditation', timestamp)
    end
    
    # Generate facility taggings (6-15 facilities)
    facility_terms = select_facility_terms(vocabs['facility'], tier)
    facility_terms.each do |term|
      taggings_to_create << build_tagging_attrs(school, term, 'facility', timestamp)
    end
    
    # Generate extracurricular taggings (3-8 activities)
    extracurricular_terms = select_extracurricular_terms(vocabs['extracurricular'], tier)
    extracurricular_terms.each do |term|
      taggings_to_create << build_tagging_attrs(school, term, 'extracurricular', timestamp)
    end
    
    # Generate language taggings (2-4 languages)
    language_terms = select_language_terms(vocabs['language'], school_type)
    language_terms.each do |term|
      taggings_to_create << build_tagging_attrs(school, term, 'language', timestamp)
    end
    
    # Generate program taggings (1-3 special programs)
    program_terms = select_program_terms(vocabs['program'], tier)
    program_terms.each do |term|
      taggings_to_create << build_tagging_attrs(school, term, 'program', timestamp)
    end
    
    # Bulk create all taggings
    Tagging.insert_all(taggings_to_create) if taggings_to_create.any?
  end
  
  # Helper to build tagging attributes
  def build_tagging_attrs(school, term, context, timestamp)
    {
      taggable_type: 'School',
      taggable_id: school.id,
      term_id: term.id,
      context: context,
      notes: "TEST_DATA_#{timestamp}",
      valid_from: Date.current,
      created_at: Time.current,
      updated_at: Time.current
    }
  end
  
  # Select curriculum terms based on tier and type
  def select_curriculum_terms(curriculum_terms, tier, school_type)
    return [] if curriculum_terms.blank?
    
    selected = []
    
    case tier
    when :premium
      # Premium schools: Full IB program or UK/US curricula
      if school_type == :international || rand < 0.7
        # IB pathway
        selected += curriculum_terms.select { |t| t.slug.include?('ib_') }.sample(rand(2..4))
      else
        # UK/US pathway
        uk_us_terms = curriculum_terms.select { |t| t.slug.match?(/uk_|us_/) }
        selected += uk_us_terms.sample(rand(2..3))
      end
      
    when :standard
      # Standard schools: Mix of local and international
      thai_curriculum = curriculum_terms.find { |t| t.slug == 'thai_national' }
      selected << thai_curriculum if thai_curriculum
      
      # Add 1-2 international programs
      int_terms = curriculum_terms.select { |t| !t.slug.include?('thai') }
      selected += int_terms.sample(rand(1..2))
      
    when :basic
      # Basic schools: Mainly Thai national with possible international option
      thai_curriculum = curriculum_terms.find { |t| t.slug == 'thai_national' }
      selected << thai_curriculum if thai_curriculum
      
      # 30% chance of one international program
      if rand < 0.3
        int_terms = curriculum_terms.select { |t| t.slug.match?(/uk_national|singapore/) }
        selected += int_terms.sample(1) if int_terms.any?
      end
    end
    
    selected.uniq
  end
  
  # Select accreditation terms based on tier
  def select_accreditation_terms(accreditation_terms, tier)
    return [] if accreditation_terms.blank?
    
    case tier
    when :premium
      # Premium schools get 2-4 accreditations
      accreditation_terms.sample(rand(2..4))
    when :standard
      # Standard schools get 1-2 accreditations
      accreditation_terms.sample(rand(1..2))
    when :basic
      # Basic schools get 0-1 accreditations
      rand < 0.4 ? accreditation_terms.sample(1) : []
    end
  end
  
  # Select facility terms based on tier
  def select_facility_terms(facility_terms, tier)
    return [] if facility_terms.blank?
    
    # Basic facilities every school should have
    basic_facilities = facility_terms.select { |t| %w[library cafeteria playground].include?(t.slug) }
    selected = basic_facilities
    
    case tier
    when :premium
      # Premium facilities (12-15 total facilities)
      premium_facilities = facility_terms.select { |t| 
        %w[olympic_pool theatre science_labs computer_lab maker_space robotics_lab 
           recording_studio sports_hall medical_center boarding_house].include?(t.slug) 
      }
      selected += premium_facilities.sample(rand(8..10))
      
    when :standard
      # Standard facilities (8-12 total facilities)
      standard_facilities = facility_terms.select { |t| 
        %w[swimming_pool gymnasium basketball_court tennis_court science_labs 
           computer_lab art_studio music_room].include?(t.slug) 
      }
      selected += standard_facilities.sample(rand(5..8))
      
    when :basic
      # Basic facilities (6-8 total facilities)
      basic_enhanced = facility_terms.select { |t| 
        %w[gymnasium basketball_court computer_lab art_studio bus_service].include?(t.slug) 
      }
      selected += basic_enhanced.sample(rand(3..5))
    end
    
    selected.uniq
  end
  
  # Select extracurricular terms
  def select_extracurricular_terms(extracurricular_terms, tier)
    return [] if extracurricular_terms.blank?
    
    # Core activities most schools have
    core_activities = extracurricular_terms.select { |t| 
      %w[basketball volleyball arts_program team_sports].include?(t.slug) 
    }
    selected = core_activities.sample(rand(2..3))
    
    case tier
    when :premium
      # Advanced extracurriculars (6-8 total)
      advanced = extracurricular_terms.select { |t| 
        %w[model_un debate robotics coding math_olympiad drama music_band choir].include?(t.slug) 
      }
      selected += advanced.sample(rand(4..6))
      
    when :standard
      # Standard extracurriculars (4-6 total)
      standard = extracurricular_terms.select { |t| 
        %w[student_council stem_club newspaper chess].include?(t.slug) 
      }
      selected += standard.sample(rand(2..4))
      
    when :basic
      # Basic extracurriculars (3-5 total)
      basic = extracurricular_terms.select { |t| 
        %w[swimming martial_arts football badminton].include?(t.slug) 
      }
      selected += basic.sample(rand(1..3))
    end
    
    selected.uniq
  end
  
  # Select language terms based on school type
  def select_language_terms(language_terms, school_type)
    return [] if language_terms.blank?
    
    selected = []
    
    # English is common in most schools
    english = language_terms.find { |t| t.slug == 'english' }
    selected << english if english
    
    # Thai for local schools
    thai = language_terms.find { |t| t.slug == 'thai' }
    selected << thai if thai && school_type != :international
    
    case school_type
    when :international
      # International schools: English + 2-3 other languages
      other_langs = language_terms.select { |t| !%w[english thai].include?(t.slug) }
      selected += other_langs.sample(rand(2..3))
      
    when :christian, :general, :thai_traditional
      # Add ESL and possibly one Asian language
      esl = language_terms.find { |t| t.slug == 'esl' }
      selected << esl if esl
      
      asian_langs = language_terms.select { |t| %w[mandarin japanese korean].include?(t.slug) }
      selected += asian_langs.sample(rand(0..1))
      
    when :buddhist, :basic
      # Mainly Thai with possible ESL
      esl = language_terms.find { |t| t.slug == 'esl' }
      selected << esl if esl && rand < 0.5
    end
    
    selected.uniq
  end
  
  # Select program terms
  def select_program_terms(program_terms, tier)
    return [] if program_terms.blank?
    
    # Common programs
    common_programs = program_terms.select { |t| 
      %w[learning_support counseling university_guidance].include?(t.slug) 
    }
    
    case tier
    when :premium
      # Premium schools: 2-3 special programs
      selected = common_programs.sample(2)
      advanced = program_terms.select { |t| 
        %w[gifted_talented leadership exchange_program summer_school].include?(t.slug) 
      }
      selected += advanced.sample(rand(1..2))
      
    when :standard
      # Standard schools: 1-2 programs
      selected = common_programs.sample(rand(1..2))
      
    when :basic
      # Basic schools: 0-1 programs
      rand < 0.6 ? common_programs.sample(1) : []
    end
  end
  
  # Generate realistic fee schedule
  def generate_fee_schedule(school, tier, timestamp)
    academic_year = "2024/25"
    
    # Fee ranges based on tier (in THB)
    fee_ranges = {
      premium: { min: 800_000, max: 1_200_000, app: (8_000..15_000), enroll: (50_000..100_000) },
      standard: { min: 400_000, max: 800_000, app: (5_000..12_000), enroll: (25_000..60_000) },
      basic: { min: 200_000, max: 450_000, app: (3_000..8_000), enroll: (10_000..30_000) }
    }
    
    range = fee_ranges[tier]
    min_tuition = rand(range[:min]..range[:max] * 0.8)
    max_tuition = rand(min_tuition * 1.2..range[:max])
    
    fee_schedule = school.school_fee_schedules.create!(
      academic_year: academic_year,
      currency: 'THB',
      min_tuition: min_tuition,
      max_tuition: max_tuition,
      application_fee: rand(range[:app]),
      enrollment_fee: rand(range[:enroll]),
      capital_levy: tier == :premium ? rand(20_000..50_000) : nil,
      boarding_fee_annual: tier == :premium && rand < 0.3 ? rand(300_000..600_000) : nil,
      transport_fee_annual: rand < 0.6 ? rand(25_000..80_000) : nil,
      is_published: true,
      notes: "TEST_DATA_#{timestamp}"
    )
  end
  
  # Generate grade offering
  def generate_grade_offering(school, tier, school_type, timestamp)
    # Determine age ranges based on school characteristics
    age_ranges = case tier
    when :premium
      if school_type == :international
        [[3, 18], [4, 16], [6, 18], [3, 12], [13, 18]].sample
      else
        [[6, 18], [6, 15], [7, 16]].sample
      end
    when :standard
      [[6, 15], [6, 18], [7, 16], [4, 12]].sample
    when :basic
      [[6, 12], [6, 15], [7, 14]].sample
    end
    
    min_age, max_age = age_ranges
    grades = generate_grade_string(min_age, max_age)
    
    school.create_school_grade_offering!(
      min_age: min_age,
      max_age: max_age,
      grades: grades,
      notes: "TEST_DATA_#{timestamp}"
    )
  end
  
  # Generate realistic grade string
  def generate_grade_string(min_age, max_age)
    grades = []
    
    if min_age <= 4
      grades << "Nursery/Pre-K"
    end
    
    if min_age <= 5
      grades << "Kindergarten"
    end
    
    # Primary grades
    primary_start = [1, [min_age - 5, 1].max].max
    primary_end = [6, max_age - 5].min
    
    if primary_start <= primary_end && primary_end >= 1
      if primary_start == primary_end
        grades << "Grade #{primary_start}"
      else
        grades << "Grades #{primary_start}-#{primary_end}"
      end
    end
    
    # Secondary grades
    if max_age >= 12
      secondary_start = [7, [min_age - 5, 7].max].max
      secondary_end = [12, max_age - 5].min
      
      if secondary_start <= secondary_end && secondary_end >= 7
        if secondary_start == secondary_end
          grades << "Grade #{secondary_start}"
        else
          grades << "Grades #{secondary_start}-#{secondary_end}"
        end
      end
    end
    
    grades.join(', ')
  end
  
  # Generate media items
  def generate_media_items(school, tier, timestamp)
    media_items = []
    
    # School logo (every school)
    media_items << {
      place_id: school.place_id,
      kind: 'logo',
      url: "https://via.placeholder.com/300x200/0066CC/FFFFFF?text=#{URI.encode_www_form_component(school.name.split.first)}",
      alt_text: "TEST_DATA - Logo for #{school.name}",
      sort_order: 1,
      created_at: Time.current,
      updated_at: Time.current
    }
    
    # Additional photos based on tier
    photo_count = case tier
    when :premium then rand(4..8)
    when :standard then rand(2..5) 
    when :basic then rand(1..3)
    end
    
    photo_types = ['campus', 'classroom', 'library', 'cafeteria', 'sports', 'lab', 'playground']
    
    photo_count.times do |i|
      photo_type = photo_types.sample
      media_items << {
        place_id: school.place_id,
        kind: 'photo',
        url: "https://via.placeholder.com/800x600/#{['FF6B6B', '4ECDC4', '45B7D1', 'F7B731', 'A55EEA'].sample}/FFFFFF?text=#{photo_type.titleize}",
        alt_text: "TEST_DATA - #{photo_type.titleize} at #{school.name}",
        sort_order: i + 2,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    
    MediaItem.insert_all(media_items) if media_items.any?
  end
end