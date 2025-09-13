require 'rails_helper'

RSpec.describe 'Critical Onboarding Business Logic', type: :system do
  # This test ensures the MOST CRITICAL user flow works:
  # New users MUST be able to find schools near them

  before do
    # Clear any existing schools to ensure clean test data
    School.destroy_all

    # Create our test schools
    @bangkok_school = create(:school, name: 'Bangkok International School', status: 'published')
    @phuket_school = create(:school, name: 'Phuket Academy', status: 'published')
    @nearby_school = create(:school, name: 'Siam Local School', status: 'published')

    @bangkok_school.place.update!(lat: 13.7563, lng: 100.5018)
    @phuket_school.place.update!(lat: 7.8804, lng: 98.3923)
    @nearby_school.place.update!(lat: 13.7600, lng: 100.5100) # Very close to Bangkok school
  end

  describe 'CRITICAL: User can find schools' do
    it 'shows schools when user provides location via URL parameters' do
      # BUSINESS RULE: Users with location params see relevant schools
      visit "/?home_lat=13.7563&home_lng=100.5018&radius=50"

      # Should see at least some schools
      expect(page).to have_content('Bangkok International School')
      expect(page).to have_content('Schools within')

      # Page should load successfully with schools
      expect(page).to have_http_status(:success)
    end

    it 'allows viewing all schools with show_all parameter' do
      # BUSINESS RULE: show_all=true shows ALL schools
      visit "/?home_lat=13.7563&home_lng=100.5018&show_all=true"

      # Should show the "All Schools" indicator
      expect(page).to have_content('All Schools')

      # Should have at least one school showing
      expect(page).to have_content('Showing')
      expect(page).to have_link('View Details')
    end

    it 'handles missing location gracefully' do
      # BUSINESS RULE: App must not crash without location
      visit "/"

      # Page should load (even if no schools shown)
      expect(page).to have_http_status(:success)
    end
  end

  describe 'CRITICAL: Distance filtering works correctly' do
    it 'respects radius parameter for filtering' do
      # Create a school that's exactly 10km away
      nearby_school = create(:school, name: 'Nearby School')
      nearby_school.place.update!(lat: 13.6563, lng: 100.5018) # ~11km from Bangkok center

      # Small radius - should not see nearby school
      visit "/?home_lat=13.7563&home_lng=100.5018&radius=5"
      expect(page).not_to have_content('Nearby School')

      # Larger radius - should see nearby school
      visit "/?home_lat=13.7563&home_lng=100.5018&radius=20"
      expect(page).to have_content('Nearby School')
    end

    it 'shows distance information for each school' do
      visit "/?home_lat=13.7563&home_lng=100.5018&radius=50"

      # Should show distance (in some format like "X km" or "X miles")
      expect(page).to have_content('km')
    end
  end

  describe 'CRITICAL: Search functionality' do
    it 'allows searching for schools by name' do
      # Use part of the actual school name for search
      search_term = @bangkok_school.name.split.first
      visit "/schools/search?q=#{search_term}&home_lat=13.7563&home_lng=100.5018"

      expect(page).to have_content(@bangkok_school.name)
      expect(page).not_to have_content(@phuket_school.name)
    end

    it 'handles empty search gracefully' do
      visit "/schools/search?q=&home_lat=13.7563&home_lng=100.5018"

      # Should not crash
      expect(page).to have_http_status(:success)
    end

    it 'shows helpful message when no results found' do
      visit "/schools/search?q=NonexistentSchool&home_lat=13.7563&home_lng=100.5018"

      # The search page shows a helpful "No schools found" message
      expect(page).to have_content('No schools found')
    end
  end

  describe 'CRITICAL: School detail pages' do
    it 'shows school details when clicked' do
      visit "/?home_lat=13.7563&home_lng=100.5018"

      # Click on school
      click_link 'Bangkok International School'

      # Should navigate to school detail page
      expect(page).to have_current_path(school_path(@bangkok_school))
      expect(page).to have_content('Bangkok International School')
    end

    it 'displays school contact information' do
      visit school_path(@bangkok_school)

      # Should have some way to contact the school
      expect(page).to have_content('Contact') ||
        have_button('Contact') ||
        have_link('Contact')
    end
  end

  describe 'CRITICAL: Performance' do
    it 'loads homepage quickly' do
      start_time = Time.current
      visit "/?home_lat=13.7563&home_lng=100.5018"
      load_time = Time.current - start_time

      # Page should load in under 5 seconds
      expect(load_time).to be < 5.seconds
    end

    it 'loads school detail page quickly' do
      start_time = Time.current
      visit school_path(@bangkok_school)
      load_time = Time.current - start_time

      # Page should load in under 3 seconds
      expect(load_time).to be < 3.seconds
    end
  end

  describe 'CRITICAL: Error handling' do
    it 'handles invalid school ID gracefully' do
      visit "/schools/99999999"

      # Should show 404 or redirect
      expect(page).to have_http_status(:not_found) ||
        have_current_path(root_path)
    end

    it 'handles invalid coordinates gracefully' do
      visit "/?home_lat=invalid&home_lng=invalid"

      # Should not crash
      expect(page).to have_http_status(:success)
    end

    it 'handles extreme coordinate values safely' do
      visit "/?home_lat=999&home_lng=999"

      # Should not crash
      expect(page).to have_http_status(:success)
    end

    it 'handles SQL injection attempts safely' do
      visit "/?home_lat=13.7563' OR '1'='1&home_lng=100.5018"

      # Should not crash or expose data
      expect(page).to have_http_status(:success)
      expect(page).not_to have_content('error in your SQL')
    end
  end

  describe 'CRITICAL: Mobile responsiveness' do
    it 'works on mobile devices' do
      # Resize to mobile viewport
      page.driver.resize(375, 667) if page.driver.respond_to?(:resize)

      visit "/?home_lat=13.7563&home_lng=100.5018"

      # Core functionality should still work - any school should be visible
      expect(page).to have_content(@bangkok_school.name)
    end
  end
end
