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
  
  desc "Show Schools sync statistics and data health report"
  task sync_schools_report: :environment do
    puts "📊 Schools Data Sync Report"
    puts "=" * 50
    puts ""
    
    # Basic counts
    total_places = Place.count
    school_places = Place.where("'school' = ANY(types) OR 'university' = ANY(types)").count
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
                                           .where.not("'school' = ANY(places.types) OR 'university' = ANY(places.types)")
    
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
  attr_reader :dry_run
  
  def initialize(dry_run: false)
    @dry_run = dry_run
    @stats = { created: 0, updated: 0, skipped: 0, errors: 0 }
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
    Place.successful_fetches
         .where("'school' = ANY(types) OR 'university' = ANY(types)")
         .where.not(lat: nil, lng: nil)
         .where.not(name: [nil, ''])
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
    # Look for existing school by place_id or google_place_id
    School.find_by(place: place) ||
    School.joins(:place).find_by(places: { place_id: place.place_id }) ||
    School.joins(:place).find_by(places: { google_place_id: place.google_place_id })
  end
  
  def create_school_from_place(place)
    school_data = extract_school_data_from_place(place)
    
    if dry_run?
      log("Would CREATE school: #{school_data[:name]}", :info)
      puts "➕ Would create: #{school_data[:name]}"
      @stats[:created] += 1
      return
    end
    
    school = School.create!(school_data)
    @stats[:created] += 1
    
    log("CREATED school #{school.id}: #{school.name}", :info)
    puts "➕ Created: #{school.name}"
  end
  
  def update_school_from_place(school, place)
    school_data = extract_school_data_from_place(place)
    
    # Check if update is needed
    needs_update = false
    changes = {}
    
    school_data.each do |key, new_value|
      next if key == :slug # Don't update slug
      
      current_value = school.send(key)
      if current_value != new_value
        needs_update = true
        changes[key] = { from: current_value, to: new_value }
      end
    end
    
    if needs_update
      if dry_run?
        log("Would UPDATE school #{school.id}: #{changes.keys.join(', ')}", :info)
        puts "🔄 Would update: #{school.name} (#{changes.keys.join(', ')})"
        @stats[:updated] += 1
        return
      end
      
      school.update!(school_data.except(:slug))
      @stats[:updated] += 1
      
      log("UPDATED school #{school.id}: #{changes.keys.join(', ')}", :info)
      puts "🔄 Updated: #{school.name}"
    else
      @stats[:skipped] += 1
      log("SKIPPED school #{school.id}: no changes needed", :debug) if school.id % 50 == 0
    end
  end
  
  def extract_school_data_from_place(place)
    {
      place: place,
      name: place.name,
      slug: generate_unique_slug(place.name),
      about: extract_about_from_place(place),
      phone: place.formatted_phone_number || place.international_phone_number,
      email: extract_email_from_place(place),
      website_url: place.website,
      address_line_1: extract_address_line_1_from_place(place),
      district: extract_district_from_place(place),
      province: extract_province_from_place(place),
      postcode: extract_postcode_from_place(place),
      country_code: extract_country_code_from_place(place),
      lat: place.lat,
      lng: place.lng,
      status: determine_school_status_from_place(place),
      ownership: determine_ownership_from_place(place),
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
  
  def extract_email_from_place(place)
    # Google Places API doesn't typically include email
    # Could be extracted from website crawl data if available
    place.website_structured_data&.dig('contact', 'email')
  end
  
  def extract_address_line_1_from_place(place)
    return nil unless place.address_components
    
    street_component = place.address_components.find { |c| c['types'].include?('route') }
    street_number = place.address_components.find { |c| c['types'].include?('street_number') }
    
    [street_number&.dig('long_name'), street_component&.dig('long_name')].compact.join(' ')
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
    if place.business_status == 'CLOSED_PERMANENTLY' || place.permanently_closed
      'suspended'
    elsif place.business_status == 'OPERATIONAL'
      'published'
    else
      'pending_review'
    end
  end
  
  def determine_ownership_from_place(place)
    # Analyze place name and types to guess ownership
    name_lower = place.name.downcase
    
    return 'private' if name_lower.include?('international') || name_lower.include?('private')
    return 'nonprofit' if name_lower.include?('public') || name_lower.include?('government')
    return 'foundation' if name_lower.include?('foundation')
    
    # Default
    'other'
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
      stats: @stats,
      summary: "#{@stats[:created]} created, #{@stats[:updated]} updated, #{@stats[:skipped]} skipped, #{@stats[:errors]} errors"
    }
    
    File.write(Rails.root.join('tmp', 'last_schools_sync.json'), results.to_json)
  end
end