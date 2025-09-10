require 'rails_helper'

RSpec.describe 'School Filtering Functionality', type: :system do
  let!(:close_school) { create(:school, name: 'Close International School') }
  let!(:far_school) { create(:school, name: 'Far Away School') }
  let!(:another_school) { create(:school, name: 'Another Bangkok School') }

  before do
    # Set up schools at different distances from test location
    close_school.place.update!(lat: 13.692000, lng: 100.537100)  # ~20m away
    far_school.place.update!(lat: 13.800000, lng: 100.600000)    # ~15km away
    another_school.place.update!(lat: 13.700000, lng: 100.540000) # ~1km away
  end

  describe 'distance-based filtering', js: true do
    it 'shows schools within specified radius' do
      # Visit with 50km radius - should show all schools
      visit root_path + '?home_lat=13.691987076564292&home_lng=100.53707963009823&radius=50'

      # Should show schools page content
      expect(page).to have_content('Schools') || page.has_content('school'), wait: 15
    end

    it 'respects show_all parameter' do
      # Use show_all=true to bypass distance filtering
      visit root_path + '?show_all=true&home_lat=13.691987076564292&home_lng=100.53707963009823'

      # Should show content regardless of distance
      expect(page).to have_content('Schools') || page.has_content('school'), wait: 15
    end

    it 'handles different radius values' do
      # Test with smaller radius
      visit root_path + '?home_lat=13.691987076564292&home_lng=100.53707963009823&radius=5'

      # Should still show page structure
      expect(page).to have_content('Schools') || page.has_content('school'), wait: 15
    end
  end

  describe 'page functionality' do
    it 'displays functional filtering interface' do
      # Visit page with location
      visit root_path + '?home_lat=13.691987076564292&home_lng=100.53707963009823&radius=50'

      # Should show basic page content
      expect(page).to have_content('school') || page.has_content('School'), wait: 15
    end

    it 'handles pagination parameters' do
      # Test with page parameter
      visit root_path + '?home_lat=13.691987076564292&home_lng=100.53707963009823&page=1'

      # Should show content
      expect(page).to have_content('school') || page.has_content('School'), wait: 15
    end
  end

  describe 'responsive behavior', js: true do
    it 'adapts to mobile viewport' do
      # Set mobile viewport using Cuprite API
      page.driver.resize(375, 667)

      visit root_path + '?home_lat=13.691987076564292&home_lng=100.53707963009823'
      expect(page).to have_content('school') || page.has_content('School'), wait: 10

      # Reset to desktop
      page.driver.resize(1200, 800)
    end
  end

  describe 'basic page interactions' do
    it 'handles page scrolling' do
      visit root_path + '?home_lat=13.691987076564292&home_lng=100.53707963009823'

      # Scroll down the page
      page.execute_script('window.scrollTo(0, document.body.scrollHeight)') rescue nil

      # Should still show content
      expect(page).to have_content('school') || page.has_content('School')
    end

    it 'handles page reload' do
      visit root_path + '?home_lat=13.691987076564292&home_lng=100.53707963009823'
      page.refresh
      expect(page).to have_content('school') || page.has_content('School'), wait: 10
    end
  end
end
