require 'rails_helper'

RSpec.describe 'Debug Page Content', type: :system do
  it 'shows what is actually on school page' do
    place = create(:place, lat: 13.7563, lng: 100.5018)
    school = create(:school, name: 'Debug Test School', place: place)

    visit school_path(school)

    # Save screenshot for inspection
    save_screenshot('/tmp/school_page_debug.png')

    # Print page content
    puts "=== PAGE HTML STRUCTURE ==="
    puts page.html[0..500]  # First 500 chars

    puts "\n=== MAIN ELEMENTS ==="
    puts "Has h1?: #{page.has_css?('h1')}"
    puts "Has main?: #{page.has_css?('main')}"
    puts "Has nav?: #{page.has_css?('nav')}"
    puts "Has #map?: #{page.has_css?('#map')}"
    puts "Has .map-container?: #{page.has_css?('.map-container')}"

    puts "\n=== TEXT CONTENT ==="
    puts "Title: #{page.title}"
    puts "H1 text: #{page.find('h1').text rescue 'No h1 found'}"

    expect(page).to have_content(school.name)
  end
end
