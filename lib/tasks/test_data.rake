# Test Data Management Rake Tasks
# Usage:
#   rails test_data:seed    - Create comprehensive test data
#   rails test_data:clean   - Remove all test data
#   rails test_data:reset   - Clean and reseed test data

namespace :test_data do
  desc "Seed comprehensive test data for development and testing"
  task seed: :environment do
    puts "🌱 Seeding test data..."
    
    # First seed taxonomy if needed
    if Vocabulary.count == 0
      puts "📚 Seeding taxonomy first..."
      load Rails.root.join("db/seeds/taxonomy.rb")
    end
    
    # Then seed test data
    load Rails.root.join("db/seeds/test_data.rb")
    
    puts "\n🎉 Test data seeding complete!"
    puts "💡 Use 'rails test_data:clean' to remove all test data"
  end
  
  desc "Clean up all test data"
  task clean: :environment do
    puts "🧹 Cleaning test data..."
    load Rails.root.join("db/seeds/cleanup_test_data.rb")
  end
  
  desc "Reset test data (clean and reseed)"
  task reset: :environment do
    puts "🔄 Resetting test data..."
    
    # Clean existing test data if cleanup file exists
    cleanup_file = Rails.root.join('tmp', 'test_data_cleanup.json')
    if File.exist?(cleanup_file)
      puts "🧹 Cleaning existing test data..."
      Rake::Task['test_data:clean'].invoke
    end
    
    # Reseed
    puts "🌱 Reseeding test data..."
    Rake::Task['test_data:seed'].invoke
  end
  
  desc "Show test data statistics"
  task stats: :environment do
    puts "📊 Test Data Statistics"
    puts "=" * 50
    
    # Count records with test data markers
    test_places = Place.where("raw_api_response->>'test_data' = 'true'").count
    test_schools = School.where("tsv @@ to_tsquery('test_data')").count
    test_taggings = Tagging.where("notes ILIKE '%test data%'").count
    test_events = Event.where("description ILIKE '%test data%'").count
    
    puts "📍 Places (test): #{test_places}"
    puts "🏫 Schools (test): #{test_schools}" 
    puts "🏷️  Taggings (test): #{test_taggings}"
    puts "📅 Events (test): #{test_events}"
    puts "💰 Fee Schedules (test): #{SchoolFeeSchedule.where('notes ILIKE ?', '%test data%').count}"
    puts "🖼️  Media Items (test): #{MediaItem.joins(:place).where("places.raw_api_response->>'test_data' = 'true'").count}"
    
    puts "\n📈 Total Database Statistics:"
    puts "📍 Total Places: #{Place.count}"
    puts "🏫 Total Schools: #{School.count}"
    puts "🏷️  Total Taggings: #{Tagging.count}"
    puts "📚 Vocabularies: #{Vocabulary.count}"
    puts "🔤 Terms: #{Term.count}"
    
    if test_schools > 0
      puts "\n🎯 Test Data Distribution:"
      School.joins(:place).where("places.raw_api_response->>'test_data' = 'true'")
            .group(:district).count.each do |district, count|
        puts "   #{district}: #{count} schools"
      end
    end
  end
end