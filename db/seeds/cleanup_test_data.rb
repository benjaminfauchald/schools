# Test Data Cleanup Script
# Run with: rails runner 'load Rails.root.join("db/seeds/cleanup_test_data.rb")'

puts "🧹 Starting test data cleanup..."

cleanup_file_path = Rails.root.join('tmp', 'test_data_cleanup.json')

unless File.exist?(cleanup_file_path)
  puts "❌ Cleanup file not found at: #{cleanup_file_path}"
  puts "💡 Make sure you've run the test data seeder first"
  exit
end

begin
  cleanup_data = JSON.parse(File.read(cleanup_file_path))
  record_ids = cleanup_data['record_ids']
  created_at = cleanup_data['created_at']
  
  puts "📅 Test data created on: #{created_at}"
  
  # 🛡️ SAFETY CHECK: Follow CLAUDE.md protection rules
  puts "⚠️  WARNING: About to delete test data"
  
  # Count records to be deleted
  total_records = 0
  record_ids.each do |model, ids|
    total_records += ids&.size || 0
  end
  
  puts "Records to delete: #{total_records} total"
  puts "Breakdown:"
  record_ids.each do |model, ids|
    next unless ids&.any?
    puts "  - #{model}: #{ids.size} records"
  end
  puts ""
  
  # Show sample records
  puts "Sample records to be deleted:"
  if record_ids['places']&.any?
    Place.where(id: record_ids['places']).limit(3).each do |place|
      puts "  - Place: #{place.name}"
    end
  end
  if record_ids['schools']&.any?
    School.where(id: record_ids['schools']).limit(3).each do |school|
      puts "  - School: #{school.name}"
    end
  end
  puts ""
  
  print "Continue? Type 'DELETE CONFIRMED' to proceed: "
  confirmation = STDIN.gets.chomp
  unless confirmation == 'DELETE CONFIRMED'
    puts "❌ Operation cancelled - test data preserved"
    exit
  end
  
  # Clean up in reverse dependency order to avoid foreign key constraints
  
  # Remove Taggings first
  if record_ids['taggings']&.any?
    deleted_count = Tagging.where(id: record_ids['taggings']).delete_all
    puts "🏷️  Deleted #{deleted_count} taggings"
  end
  
  # Remove Events
  if record_ids['events']&.any?
    deleted_count = Event.where(id: record_ids['events']).delete_all
    puts "📅 Deleted #{deleted_count} events"
  end
  
  # Remove Media Items
  if record_ids['media_items']&.any?
    deleted_count = MediaItem.where(id: record_ids['media_items']).delete_all
    puts "🖼️  Deleted #{deleted_count} media items"
  end
  
  # Remove School Grade Offerings
  if record_ids['school_grade_offerings']&.any?
    deleted_count = SchoolGradeOffering.where(id: record_ids['school_grade_offerings']).delete_all
    puts "🎓 Deleted #{deleted_count} grade offerings"
  end
  
  # Remove School Fee Schedules (will cascade to fee bands)
  if record_ids['school_fee_schedules']&.any?
    deleted_count = SchoolFeeSchedule.where(id: record_ids['school_fee_schedules']).delete_all
    puts "💰 Deleted #{deleted_count} fee schedules (including fee bands)"
  end
  
  # Remove Schools
  if record_ids['schools']&.any?
    deleted_count = School.where(id: record_ids['schools']).delete_all
    puts "🏫 Deleted #{deleted_count} schools"
  end
  
  # Remove Places last
  if record_ids['places']&.any?
    deleted_count = Place.where(id: record_ids['places']).delete_all
    puts "📍 Deleted #{deleted_count} places"
  end
  
  # Remove the cleanup file
  File.delete(cleanup_file_path)
  puts "🗑️  Removed cleanup file"
  
  puts "\n✅ Test data cleanup complete!"
  puts "🧹 All test data has been successfully removed from the database"
  
rescue JSON::ParserError => e
  puts "❌ Error parsing cleanup file: #{e.message}"
  exit 1
rescue StandardError => e
  puts "❌ Error during cleanup: #{e.message}"
  puts "🔍 You may need to manually clean up some records"
  exit 1
end