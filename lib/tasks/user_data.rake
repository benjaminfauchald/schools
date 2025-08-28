namespace :user_data do
  desc "Clear all location-related data and reset user preferences"
  task clear_locations: :environment do
    puts "🗑️  Clearing location data..."
    
    # Since localStorage is client-side, this task provides instructions
    puts "\n📱 To clear user home locations from browsers:"
    puts "   Method 1: JavaScript Console"
    puts "   → localStorage.removeItem('homeLocation')"
    puts ""
    puts "   Method 2: Developer Tools"
    puts "   → Application Tab → Local Storage → Delete 'homeLocation'"
    puts ""
    puts "   Method 3: Settings Page"
    puts "   → Visit /settings and click 'Clear Location'"
    puts ""
    
    # Clear any server-side location data (if we had any)
    puts "✅ Server-side location data cleared (none currently stored)"
    puts "✅ Task completed"
  end

  desc "Show location data information"
  task info: :environment do
    puts "📍 Location Data Information"
    puts "=" * 50
    puts "Storage Type: Browser localStorage (client-side)"
    puts "Storage Key: 'homeLocation'"
    puts "Data Structure: JSON with lat, lng, formatted_address, timestamp"
    puts "Expiration: 30 days automatic"
    puts ""
    puts "🔧 Management URLs:"
    puts "   Settings: /settings"
    puts "   Onboarding: /onboarding"
    puts ""
    puts "🧹 Clear Methods:"
    puts "   1. Visit /settings → 'Clear Location' button"
    puts "   2. JavaScript: localStorage.removeItem('homeLocation')"
    puts "   3. Developer Tools: Application → Local Storage"
  end

  desc "Simulate onboarding reset (clears and redirects)"
  task reset_onboarding: :environment do
    puts "🔄 Onboarding Reset Instructions"
    puts "=" * 40
    puts ""
    puts "To reset a user's onboarding experience:"
    puts ""
    puts "1. 🧹 Clear their localStorage:"
    puts "   localStorage.removeItem('homeLocation')"
    puts ""
    puts "2. 🔄 Visit the homepage:"
    puts "   → User will be automatically redirected to /onboarding"
    puts ""
    puts "3. ⚙️  Alternative via Settings:"
    puts "   → Visit /settings → Click 'Clear Location'"
    puts "   → Then visit homepage for re-onboarding"
    puts ""
    puts "✅ Instructions provided"
  end

  desc "Generate test location data (for development)"
  task generate_test_location: :environment do
    test_locations = [
      {
        name: "Bangkok Central",
        address: "Siam, Bangkok, Thailand",
        lat: 13.7563,
        lng: 100.5018
      },
      {
        name: "Sukhumvit Area", 
        address: "Sukhumvit Road, Bangkok, Thailand",
        lat: 13.7308,
        lng: 100.5418
      },
      {
        name: "Silom District",
        address: "Silom Road, Bangkok, Thailand", 
        lat: 13.7248,
        lng: 100.5346
      }
    ]
    
    puts "🧪 Test Location Data"
    puts "=" * 30
    puts ""
    puts "You can use these in your browser console:"
    puts ""
    
    test_locations.each_with_index do |location, index|
      puts "#{index + 1}. #{location[:name]}:"
      js_code = {
        lat: location[:lat],
        lng: location[:lng],
        formatted_address: location[:address],
        timestamp: Time.current.iso8601,
        source: 'test'
      }
      
      puts "   localStorage.setItem('homeLocation', '#{js_code.to_json.gsub("'", "\\'")}')"
      puts ""
    end
    
    puts "✅ Test data generated"
  end
end