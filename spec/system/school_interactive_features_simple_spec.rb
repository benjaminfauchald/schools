require 'rails_helper'

RSpec.describe 'School Interactive Features', type: :system do
  let(:place) { create(:place, lat: 13.7563, lng: 100.5018, formatted_address: '123 School Street, Bangkok') }
  let(:school) { create(:school, name: 'Interactive Test School', place: place) }
  let(:facebook_user) { create(:user, :facebook_user) }

  describe 'basic page interactions' do
    it 'loads school detail page' do
      visit school_path(school)
      expect(page).to have_content(school.name)
      expect(page).to have_css('h1')
    end

    it 'displays school information' do
      visit school_path(school)
      expect(page).to have_content(school.place.formatted_address)
    end

    it 'has proper page structure' do
      visit school_path(school)
      expect(page).to have_css('main')
      expect(page).to have_css('nav')
    end
  end

  describe 'responsive design' do
    it 'works on mobile viewport' do
      # Cuprite uses different syntax for window resize
      page.driver.resize(375, 667)
      visit school_path(school)
      expect(page).to have_content(school.name)
    end

    it 'works on desktop viewport' do
      # Cuprite uses different syntax for window resize
      page.driver.resize(1920, 1080)
      visit school_path(school)
      expect(page).to have_content(school.name)
    end
  end
end
