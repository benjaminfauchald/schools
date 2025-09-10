require 'rails_helper'

RSpec.describe 'Critical Working Features - Must Not Break', type: :system do
  # These tests verify ACTUAL WORKING FEATURES that users rely on
  # They will FAIL if someone breaks these features
  
  let!(:bangkok_school) { create(:school, name: 'Bangkok International School') }
  let!(:phuket_school) { create(:school, name: 'Phuket Academy') }
  
  before do
    bangkok_school.place.update!(
      lat: 13.7563, 
      lng: 100.5018,
      formatted_address: '123 Sukhumvit Road, Bangkok 10110'
    )
    phuket_school.place.update!(
      lat: 7.8804, 
      lng: 98.3923,
      formatted_address: '456 Beach Road, Phuket 83000'
    )
  end

  describe 'WORKING: Users can find schools by location' do
    it 'shows nearby schools when location is provided' do
      # This WORKS - users depend on it
      visit "/?home_lat=13.7563&home_lng=100.5018&radius=50"
      
      # User sees Bangkok school
      expect(page).to have_content('Bangkok International School')
      expect(page).to have_content('Sukhumvit Road')
      
      # User does NOT see distant Phuket school
      expect(page).not_to have_content('Phuket Academy')
    end

    it 'calculates and displays distance correctly' do
      # This WORKS - users see distance to schools
      visit "/?home_lat=13.7563&home_lng=100.5018&radius=50"
      
      # Distance should be shown somewhere on the page
      expect(page.text).to match(/\d+(\.\d+)?\s*(km|mi)/i) || 
        have_content('0 km')
    end
  end

  describe 'WORKING: School detail pages show information' do
    it 'displays school name and basic information' do
      # This WORKS - critical for users researching schools
      visit "/schools/#{bangkok_school.slug || bangkok_school.id}"
      
      expect(page).to have_content('Bangkok International School')
      expect(page).to have_content('Sukhumvit Road')
      expect(page.status_code).to eq(200)
    end

    it 'shows contact options for schools' do
      # This WORKS - users need to contact schools
      visit "/schools/#{bangkok_school.slug || bangkok_school.id}"
      
      # Should have some form of contact (button, link, or form)
      expect(page).to have_content('Ask About This School') || 
        have_button(/contact/i) || 
        have_link(/contact/i)
    end
  end

  describe 'WORKING: Search functionality finds schools' do
    it 'finds schools by name search' do
      # This WORKS - users search for specific schools
      visit "/schools/search?q=Bangkok&home_lat=13.7563&home_lng=100.5018"
      
      # Returns JSON with results
      expect(page).to have_content('Bangkok International School') || 
        have_content('"name":"Bangkok International School"')
    end

    it 'returns empty results for non-matching search' do
      # This WORKS - handles no results gracefully
      visit "/schools/search?q=NonexistentSchoolXYZ123&home_lat=13.7563&home_lng=100.5018"
      
      # Should show a "no results" message
      expect(page).to have_content('No schools found')
      expect(page.status_code).to eq(200) # Should not error
    end
  end

  describe 'WORKING: Show all schools option' do
    it 'displays all schools when show_all=true' do
      # This WORKS - users can browse all schools
      visit "/?home_lat=13.7563&home_lng=100.5018&show_all=true"
      
      # Should see BOTH schools regardless of distance
      expect(page).to have_content('Bangkok International School')
      expect(page).to have_content('Phuket Academy')
    end
  end

  describe 'WORKING: Error handling prevents crashes' do
    it 'handles invalid coordinates without crashing' do
      # This WORKS - bad input doesn't break the app
      visit "/?home_lat=invalid&home_lng=invalid"
      
      # Page should still load (even if showing no results)
      expect(page.status_code).to eq(200)
      expect(page).not_to have_content('Application Error')
      expect(page).not_to have_content('We\'re sorry, but something went wrong')
    end

    it 'returns 404 for non-existent schools' do
      # This WORKS - proper error handling
      visit "/schools/99999999"
      
      expect(page.status_code).to eq(404)
      expect(page).not_to have_content('Application Error')
    end

    it 'handles missing location parameters gracefully' do
      # This WORKS - doesn't crash without params
      visit "/"
      
      expect(page.status_code).to eq(200)
      # May show no schools or redirect to onboarding, but shouldn't crash
      expect(page).not_to have_content('NameError')
      expect(page).not_to have_content('undefined method')
    end
  end

  describe 'WORKING: Mobile responsiveness' do
    it 'works on mobile viewport sizes' do
      # This WORKS - mobile users can use the site
      page.driver.resize(375, 812) if page.driver.respond_to?(:resize)
      
      visit "/?home_lat=13.7563&home_lng=100.5018"
      
      # Core functionality still works
      expect(page).to have_content('Bangkok International School')
      expect(page.status_code).to eq(200)
    end
  end

  describe 'WORKING: Performance is acceptable' do
    it 'loads homepage in reasonable time' do
      # This WORKS - pages load fast enough
      start_time = Time.current
      visit "/?home_lat=13.7563&home_lng=100.5018"
      load_time = Time.current - start_time
      
      # Should load in under 5 seconds (generous limit for CI)
      expect(load_time).to be < 5.0
      expect(page.status_code).to eq(200)
    end

    it 'loads school detail page in reasonable time' do
      # This WORKS - detail pages are fast
      start_time = Time.current
      visit "/schools/#{bangkok_school.id}"
      load_time = Time.current - start_time
      
      expect(load_time).to be < 5.0
      expect(page).to have_content('Bangkok International School')
    end
  end

  describe 'WORKING: Critical user journeys' do
    it 'user can browse schools and view details' do
      # Complete user journey that MUST work
      
      # Step 1: User arrives with location
      visit "/?home_lat=13.7563&home_lng=100.5018"
      expect(page).to have_content('Bangkok International School')
      
      # Step 2: User clicks on a school
      click_link 'Bangkok International School'
      
      # Step 3: User sees school details
      expect(page).to have_current_path("/schools/#{bangkok_school.id}")
      expect(page).to have_content('Bangkok International School')
      expect(page).to have_content('Sukhumvit Road')
    end

    it 'user can search and find specific schools' do
      # Search journey that MUST work
      
      # User searches for "International"
      visit "/schools/search?q=International&home_lat=13.7563&home_lng=100.5018"
      
      # Should find the school
      expect(page.body).to include('Bangkok International School')
    end
  end

  describe 'WORKING: Data integrity' do
    it 'shows correct school information' do
      # Verify data is displayed correctly
      school = create(:school, 
        name: 'Test School 2024',
        about: 'A great school for testing'
      )
      school.place.update!(
        formatted_address: '789 Test Street, Bangkok'
      )
      
      visit "/schools/#{school.id}"
      
      # All key information should be present
      expect(page).to have_content('Test School 2024')
      expect(page).to have_content('Test Street')
    end

    it 'maintains data consistency across pages' do
      # School count should be consistent
      visit "/?home_lat=13.7563&home_lng=100.5018&show_all=true"
      
      # Should see both schools we created
      expect(page).to have_content('Bangkok International School')
      expect(page).to have_content('Phuket Academy')
    end
  end
end