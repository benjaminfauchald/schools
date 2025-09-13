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

    it 'does not create redirect loop when setting location' do
      # Visit onboarding page
      visit '/onboarding'
      expect(page).to have_content('Set Your Home Location')

      # The onboarding page should not have location controller that redirects
      # Check that we stay on the onboarding page
      expect(current_path).to eq('/onboarding')

      # Fill in address
      fill_in 'Home Address', with: '123 Test Street, Bangkok'

      # We should still be on onboarding (not redirected)
      expect(current_path).to eq('/onboarding')
    end

    it 'completes onboarding flow and redirects to home' do
      # Visit onboarding
      visit '/onboarding'

      # Execute JavaScript to simulate setting location
      page.execute_script("
        localStorage.setItem('homeLocation', JSON.stringify({
          lat: 13.7563,
          lng: 100.5018,
          formatted_address: 'Bangkok, Thailand',
          timestamp: new Date().toISOString()
        }));
      ")

      # Now visit home page WITH location parameters - should not redirect back to onboarding
      visit root_path + '?home_lat=13.7563&home_lng=100.5018'

      # Should NOT be redirected back to onboarding
      expect(current_path).not_to eq('/onboarding')
      expect(page).not_to have_content('Set Your Home Location')
    end

    it 'redirects with location parameters after setting location', js: true do
      visit '/onboarding'

      # Fill in an address
      fill_in 'Home Address', with: '123 Test Street, Bangkok'

      # Mock the geocoding response and call save function
      page.execute_script("
        window.selectedLocation = {
          lat: 13.7563,
          lng: 100.5018,
          formatted_address: 'Bangkok, Thailand',
          source: 'test'
        };
        saveLocationAndComplete();
      ")

      # Wait for redirect to happen
      expect(page).to have_current_path(/home_lat=13\.7563/, wait: 5)
      expect(current_url).to include('home_lng=100.5018')
    end

    it 'handles map button interactions correctly', js: true do
      visit '/onboarding'

      # Click "Use Map Instead" button
      click_button 'Use Map Instead'

      # Map section should be visible
      expect(page).to have_css('[data-onboarding-location-target="mapStep"]:not(.hidden)', wait: 3)

      # Confirm button should exist and be disabled initially
      expect(page).to have_button('Confirm This Location', disabled: true)

      # Back button should work
      click_button 'Back to Address Input'
      expect(page).to have_css('#address-step:not(.hidden)')
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
