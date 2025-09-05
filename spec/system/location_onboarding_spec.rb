require 'rails_helper'

RSpec.describe 'Location Onboarding Workflow', type: :system do
  let!(:bangkok_school) { create(:school, name: 'Bangkok Test School') }
  
  before do
    # Set up school with proper Bangkok coordinates
    bangkok_school.place.update!(lat: 13.692000, lng: 100.537100)
  end
  
  describe 'user location workflow' do
    it 'shows schools when location is provided via URL' do
      # User visits with location parameters (like from onboarding or bookmark)
      visit root_path + '?home_lat=13.691987076564292&home_lng=100.53707963009823&radius=50'
      
      # Should show schools page content
      expect(page).to have_content('Schools') || page.has_content('school'), wait: 10
      expect(page.status_code).to eq(200)
    end
    
    it 'handles show_all parameter to bypass distance filtering' do
      # User wants to see all schools regardless of location
      visit root_path + '?show_all=true&home_lat=13.691987076564292&home_lng=100.53707963009823'
      
      # Should show schools page
      expect(page).to have_content('Schools') || page.has_content('school'), wait: 10
      expect(page.status_code).to eq(200)
    end
    
    it 'can access onboarding page' do
      visit '/onboarding'
      expect(page.status_code).to eq(200)
    end
    
    it 'displays basic page structure' do
      # Visit with location to ensure content loads
      visit root_path + '?home_lat=13.691987076564292&home_lng=100.53707963009823'
      
      # Check for basic page elements (navigation, content area, etc.)
      expect(page).to have_content('Schools') || page.has_content('school'), wait: 10
    end
  end
  
  describe 'page accessibility' do  
    it 'allows access to root page' do
      visit root_path
      expect(page.status_code).to eq(200)
    end
    
    it 'handles page refresh gracefully' do
      visit root_path + '?home_lat=13.691987076564292&home_lng=100.53707963009823'
      page.refresh
      expect(page).to have_content('Schools') || page.has_content('school'), wait: 10
    end
  end
end