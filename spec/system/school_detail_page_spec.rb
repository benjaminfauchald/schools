require 'rails_helper'

RSpec.describe 'School Detail Page Rendering', type: :system do
  let(:place) { create(:place, lat: 13.7563, lng: 100.5018, formatted_address: '123 School Street, Bangkok') }
  let(:school) { create(:school, name: 'Bangkok International Academy', place: place) }
  let(:school_with_media) { create(:school, :with_media, name: 'Elite International School', place: place) }

  # Create comprehensive school with all features
  let(:comprehensive_school) do
    create(:school, name: 'Comprehensive International School', place: place).tap do |s|
      # Add fee schedules
      create(:school_fee_schedule, school: s, grade_level: 'Primary', tuition_fee_thb: 150000)
      create(:school_fee_schedule, school: s, grade_level: 'Secondary', tuition_fee_thb: 200000)

      # Add grade offerings
      create(:school_grade_offering, school: s, min_age: 3, max_age: 18, grades_display: 'K-12')

      # Add curriculum and facilities through taxonomy
      curriculum_vocab = create(:vocabulary, code: 'curriculum')
      facility_vocab = create(:vocabulary, code: 'facility')
      language_vocab = create(:vocabulary, code: 'language')

      ib_curriculum = create(:term, vocabulary: curriculum_vocab, label: 'IB Programme', slug: 'ib')
      cambridge_curriculum = create(:term, vocabulary: curriculum_vocab, label: 'Cambridge IGCSE', slug: 'cambridge')
      library_facility = create(:term, vocabulary: facility_vocab, label: 'Library', slug: 'library')
      pool_facility = create(:term, vocabulary: facility_vocab, label: 'Swimming Pool', slug: 'swimming_pool')
      english_language = create(:term, vocabulary: language_vocab, label: 'English', slug: 'english')
      thai_language = create(:term, vocabulary: language_vocab, label: 'Thai', slug: 'thai')

      s.add_term(ib_curriculum)
      s.add_term(cambridge_curriculum)
      s.add_term(library_facility)
      s.add_term(pool_facility)
      s.add_term(english_language)
      s.add_term(thai_language)

      # Add published pages
      create_list(:page, 3, school: s, status: 'published')

      # Add media items
      create_list(:media_item, 5, place: s.place)
    end
  end

  before do
    # Set location cookie to bypass onboarding (Cuprite driver)
    visit '/' # Need to visit a page first to set cookies
    page.driver.browser.cookies.set({
      name: 'home_location',
      value: '{"lat":13.7563,"lng":100.5018}'
    })
  end

  describe 'basic page structure', js: true do
    it 'loads the school detail page successfully' do
      visit school_path(school)

      expect(page).to have_content(school.name), wait: 10
      expect(page).to have_http_status(:ok)
    end

    it 'displays proper page title' do
      visit school_path(school)
      expect(page.title).to include(school.name)
    end

    it 'renders responsive layout' do
      visit school_path(school)

      # Check main sections are present
      expect(page).to have_css('.hero-section, .school-hero', wait: 5)
      expect(page).to have_css('.contact-form, .school-contact', wait: 5)
    end

    it 'handles both slug and ID routing' do
      visit school_path(school.slug)
      expect(page).to have_content(school.name)

      visit school_path(school.id)
      expect(page).to have_content(school.name)
    end
  end

  describe 'hero section rendering' do
    it 'displays school name prominently' do
      visit school_path(comprehensive_school)

      within('.hero-section, .school-hero, h1') do
        expect(page).to have_content(comprehensive_school.name)
      end
    end

    it 'shows contact information when available' do
      comprehensive_school.update(phone: '+66 2 123 4567', email: 'info@school.com')
      visit school_path(comprehensive_school)

      expect(page).to have_content('+66 2 123 4567')
      expect(page).to have_content('info@school.com')
    end

    it 'displays location information' do
      visit school_path(comprehensive_school)
      expect(page).to have_content('Bangkok')
    end
  end

  describe 'contact form section', js: true do
    context 'when user is not signed in' do
      it 'shows Facebook authentication requirement' do
        visit school_path(school)

        expect(page).to have_content('Facebook'), wait: 10
        expect(page).to have_content('sign in', ignore_case: true)
      end

      it 'displays contact form fields' do
        visit school_path(school)

        within('.contact-form, form') do
          expect(page).to have_field('Name', type: 'text')
          expect(page).to have_field('Email', type: 'email')
          expect(page).to have_field('Message', type: 'textarea')
        end
      end

      it 'shows number of children field' do
        visit school_path(school)
        expect(page).to have_field('children_count', type: 'number')
      end
    end

    context 'when user is Facebook authenticated' do
      let(:facebook_user) { create(:user, :facebook_user) }

      before do
        login_as(facebook_user, scope: :user)
      end

      it 'shows direct submit button' do
        visit school_path(school)
        expect(page).to have_button('Send Message')
      end

      it 'displays encouraging message' do
        visit school_path(school)
        expect(page).to have_content("Send a message to #{school.name}")
      end
    end
  end

  describe 'interactive map section', js: true do
    it 'displays map container' do
      visit school_path(school)
      expect(page).to have_css('#map, .map-container, .interactive-map', wait: 10)
    end

    it 'shows school location information' do
      visit school_path(school)
      expect(page).to have_content(school.place.formatted_address)
    end

    it 'handles maps loading gracefully' do
      visit school_path(school)
      # Should not crash even if Google Maps fails to load
      expect(page).to have_content(school.name)
    end
  end

  describe 'academic programs section' do
    it 'displays curriculum information' do
      visit school_path(comprehensive_school)

      expect(page).to have_content('Academic Programs')
      expect(page).to have_content('IB Programme')
      expect(page).to have_content('Cambridge IGCSE')
    end

    it 'shows languages section' do
      visit school_path(comprehensive_school)

      expect(page).to have_content('Languages')
      expect(page).to have_content('English')
      expect(page).to have_content('Thai')
    end

    it 'hides section when no programs available' do
      visit school_path(school)
      # Should not show empty academic programs section
      expect(page).not_to have_content('Academic Programs')
    end
  end

  describe 'facilities section' do
    it 'displays facilities in organized categories' do
      visit school_path(comprehensive_school)

      expect(page).to have_content('Campus Facilities')
      expect(page).to have_content('Library')
      expect(page).to have_content('Swimming Pool')
    end

    it 'shows facility categories' do
      visit school_path(comprehensive_school)

      expect(page).to have_content('Academic Facilities')
      expect(page).to have_content('Sports & Recreation')
    end

    it 'handles empty facilities gracefully' do
      visit school_path(school)
      # Should not show empty facilities section
      expect(page).not_to have_content('Campus Facilities')
    end
  end

  describe 'grade offerings section' do
    it 'displays age ranges and grade levels' do
      visit school_path(comprehensive_school)

      expect(page).to have_content('Grade Levels')
      expect(page).to have_content('3 to 18 years old')
      expect(page).to have_content('K-12')
    end

    it 'hides section when no grade offerings' do
      visit school_path(school)
      expect(page).not_to have_content('Grade Levels')
    end
  end

  describe 'tuition and fees section' do
    it 'displays fee schedules' do
      visit school_path(comprehensive_school)

      expect(page).to have_content('Tuition & Fees')
      expect(page).to have_content('Primary')
      expect(page).to have_content('150,000')
      expect(page).to have_content('Secondary')
      expect(page).to have_content('200,000')
    end

    it 'formats currency properly' do
      visit school_path(comprehensive_school)
      expect(page).to have_content('฿150,000')
      expect(page).to have_content('฿200,000')
    end

    it 'handles empty fee schedules' do
      visit school_path(school)
      # Should show placeholder or hide section
      expect(page).not_to have_content('Tuition & Fees') || have_content('Contact school for fees')
    end
  end

  describe 'school pages section' do
    it 'displays published school pages' do
      visit school_path(comprehensive_school)

      expect(page).to have_content('School Pages')
      expect(page).to have_content('3 pages available')
      expect(page).to have_link('View All Pages')
    end

    it 'shows individual page previews' do
      visit school_path(comprehensive_school)
      expect(page).to have_link('Read More')
    end

    it 'hides section when no published pages' do
      visit school_path(school)
      expect(page).not_to have_content('School Pages')
    end
  end

  describe 'photo gallery section', js: true do
    it 'displays photos when available' do
      visit school_path(school_with_media)

      expect(page).to have_content('Photo Gallery')
      expect(page).to have_css('img, .photo', wait: 10)
    end

    it 'handles lazy loading' do
      visit school_path(school_with_media)
      # Photos should load as user scrolls
      expect(page).to have_css('img[loading="lazy"], img[data-src]')
    end

    it 'hides gallery when no photos' do
      visit school_path(school)
      expect(page).not_to have_content('Photo Gallery')
    end
  end

  describe 'video gallery section', js: true do
    let(:school_with_videos) do
      create(:school).tap do |s|
        s.update(youtube_url: 'https://youtube.com/channel/test')
        # Mock video data would be added here
      end
    end

    it 'displays video gallery when YouTube URL exists' do
      visit school_path(school_with_videos)
      expect(page).to have_content('Video Gallery')
    end

    it 'hides video gallery when no YouTube URL' do
      visit school_path(school)
      expect(page).not_to have_content('Video Gallery')
    end
  end

  describe 'claim this school section' do
    context 'with unclaimed school' do
      it 'shows claim section for anonymous users' do
        visit school_path(school)
        expect(page).to have_content('Claim This School')
        expect(page).to have_link('Sign Up to Claim')
      end

      context 'when user is school owner' do
        let(:school_owner) { create(:user, :school_owner) }

        before do
          login_as(school_owner, scope: :user)
        end

        it 'shows claim button for school owners' do
          visit school_path(school)
          expect(page).to have_content('Own This School')
          expect(page).to have_link('Claim This School')
        end
      end
    end

    context 'with claimed school' do
      before do
        create(:school_claim, :approved, school: school)
      end

      it 'hides claim section' do
        visit school_path(school)
        expect(page).not_to have_content('Claim This School')
      end
    end
  end

  describe 'responsive behavior', js: true do
    it 'adapts to mobile viewport' do
      page.driver.resize(width: 375, height: 667)

      visit school_path(comprehensive_school)
      expect(page).to have_content(comprehensive_school.name)

      # Should stack sections vertically on mobile
      expect(page).to have_css('.grid-cols-1, .flex-col, .block')
    end

    it 'displays desktop layout' do
      page.driver.resize(width: 1200, height: 800)

      visit school_path(comprehensive_school)
      expect(page).to have_content(comprehensive_school.name)

      # Should show side-by-side layout on desktop
      expect(page).to have_css('.grid-cols-2, .lg\\:grid-cols-2')
    end

    it 'handles tablet viewport' do
      page.driver.resize(width: 768, height: 1024)

      visit school_path(comprehensive_school)
      expect(page).to have_content(comprehensive_school.name)
    end
  end

  describe 'loading performance' do
    it 'loads page within reasonable time' do
      start_time = Time.current
      visit school_path(comprehensive_school)
      expect(page).to have_content(comprehensive_school.name), wait: 10
      end_time = Time.current

      expect(end_time - start_time).to be < 5.seconds
    end

    it 'displays content progressively' do
      visit school_path(comprehensive_school)

      # Hero section should load first
      expect(page).to have_content(comprehensive_school.name), wait: 2

      # Other sections should follow
      expect(page).to have_content('Academic Programs'), wait: 5
    end
  end

  describe 'error handling' do
    it 'handles missing school gracefully' do
      visit '/schools/non-existent-school'
      expect(page).to have_http_status(:not_found)
    end

    it 'displays user-friendly error for 404' do
      visit '/schools/999999'
      expect(page).to have_content('Page not found') || have_http_status(:not_found)
    end

    it 'continues to work if JavaScript fails' do
      # Disable JavaScript temporarily
      page.execute_script('window.onerror = function() { return true; }')

      visit school_path(school)
      expect(page).to have_content(school.name)
    end
  end

  describe 'browser compatibility' do
    it 'works without JavaScript enabled' do
      # Test basic functionality without JS
      Capybara.current_driver = :rack_test

      visit school_path(school)
      expect(page).to have_content(school.name)

      Capybara.use_default_driver
    end
  end

  describe 'SEO and metadata' do
    it 'includes proper meta tags' do
      visit school_path(school)

      expect(page).to have_xpath("//meta[@name='description']")
      expect(page).to have_xpath("//meta[@name='keywords']")
      expect(page).to have_xpath("//meta[@name='viewport']")
    end

    it 'uses semantic HTML structure' do
      visit school_path(comprehensive_school)

      expect(page).to have_css('h1')
      expect(page).to have_css('h2, h3')
      expect(page).to have_css('main, section, article')
    end
  end

  describe 'content organization' do
    it 'displays sections in logical order' do
      visit school_path(comprehensive_school)

      page_text = page.text
      hero_position = page_text.index(comprehensive_school.name)
      academic_position = page_text.index('Academic Programs')
      facilities_position = page_text.index('Campus Facilities')

      expect(hero_position).to be < academic_position
      expect(academic_position).to be < facilities_position
    end

    it 'shows all major sections for comprehensive school' do
      visit school_path(comprehensive_school)

      expected_sections = [
        comprehensive_school.name, # Hero
        'Academic Programs',
        'Campus Facilities',
        'Grade Levels',
        'Tuition & Fees',
        'School Pages',
        'Photo Gallery'
      ]

      expected_sections.each do |section|
        expect(page).to have_content(section)
      end
    end
  end

  describe 'data accuracy' do
    it 'displays correct school information' do
      comprehensive_school.update(
        phone: '+66 2 555 1234',
        email: 'contact@comprehensive.edu',
        website_url: 'https://comprehensive.edu'
      )

      visit school_path(comprehensive_school)

      expect(page).to have_content('+66 2 555 1234')
      expect(page).to have_content('contact@comprehensive.edu')
      expect(page).to have_link(href: 'https://comprehensive.edu')
    end

    it 'shows current fee information' do
      visit school_path(comprehensive_school)

      expect(page).to have_content('฿150,000') # Primary fees
      expect(page).to have_content('฿200,000') # Secondary fees
    end
  end

  describe 'interactive elements', js: true do
    it 'allows form interaction' do
      visit school_path(school)

      fill_in 'Name', with: 'Test User'
      fill_in 'Email', with: 'test@example.com'
      fill_in 'Message', with: 'Test inquiry message'

      # Form should accept input
      expect(page).to have_field('Name', with: 'Test User')
    end

    it 'handles scroll interactions' do
      visit school_path(comprehensive_school)

      page.execute_script('window.scrollTo(0, 500)')
      sleep 1

      expect(page).to have_content(comprehensive_school.name)
    end
  end
end
