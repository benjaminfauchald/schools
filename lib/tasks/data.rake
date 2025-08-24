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