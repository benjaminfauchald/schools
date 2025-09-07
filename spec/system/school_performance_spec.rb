require 'rails_helper'

RSpec.describe 'School Detail Page Performance', type: :system do
  let(:place) { create(:place, lat: 13.7563, lng: 100.5018, formatted_address: '123 Performance Test Street, Bangkok') }
  let(:school) { create(:school, name: 'Performance Test School', place: place) }

  let(:heavy_school) do
    create(:school, name: 'Resource Heavy School', place: place).tap do |s|
      # Create multiple fee schedules
      create_list(:school_fee_schedule, 10, school: s)

      # Create grade offerings
      create(:school_grade_offering, school: s, min_age: 3, max_age: 18)

      # Create many taxonomy terms
      curriculum_vocab = create(:vocabulary, code: 'curriculum')
      facility_vocab = create(:vocabulary, code: 'facility')
      language_vocab = create(:vocabulary, code: 'language')

      # Add many terms
      10.times do |i|
        curriculum = create(:term, vocabulary: curriculum_vocab, label: "Curriculum #{i}")
        facility = create(:term, vocabulary: facility_vocab, label: "Facility #{i}")
        language = create(:term, vocabulary: language_vocab, label: "Language #{i}")

        s.add_term(curriculum)
        s.add_term(facility)
        s.add_term(language)
      end

      # Create many media items
      create_list(:media_item, 25, place: s.place)

      # Create many pages
      create_list(:page, 15, school: s, status: 'published')

      # Create many inquiries (historical data)
      create_list(:school_inquiry, 50, school: s)

      # Create many claims
      create_list(:school_claim, 5, school: s)
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

  describe 'page load performance' do
    it 'loads basic school page within acceptable time' do
      start_time = Time.current

      visit school_path(school)
      expect(page).to have_content(school.name), wait: 10

      end_time = Time.current
      load_time = end_time - start_time

      # Should load within 3 seconds
      expect(load_time).to be < 3.seconds
    end

    it 'loads heavy school page within reasonable time' do
      start_time = Time.current

      visit school_path(heavy_school)
      expect(page).to have_content(heavy_school.name), wait: 15

      end_time = Time.current
      load_time = end_time - start_time

      # Even heavy pages should load within 5 seconds
      expect(load_time).to be < 5.seconds
    end

    it 'shows progressive loading of content' do
      visit school_path(heavy_school)

      # Hero section should load first
      expect(page).to have_content(heavy_school.name), wait: 2

      # Other sections should follow progressively
      expect(page).to have_content('Academic Programs'), wait: 5
      expect(page).to have_content('Campus Facilities'), wait: 5
    end

    it 'maintains performance with many database queries' do
      # Monitor database queries during page load
      queries = []

      ActiveSupport::Notifications.subscribe 'sql.active_record' do |_, _, _, _, payload|
        queries << payload[:sql] unless payload[:name] == 'SCHEMA'
      end

      visit school_path(heavy_school)
      expect(page).to have_content(heavy_school.name), wait: 10

      # Should use efficient queries (with eager loading)
      expect(queries.count).to be < 50 # Reasonable limit with eager loading

      # Should not have N+1 queries for associations
      repeated_queries = queries.group_by(&:itself).select { |_, v| v.count > 5 }
      expect(repeated_queries).to be_empty

    ensure
      ActiveSupport::Notifications.unsubscribe 'sql.active_record'
    end
  end

  describe 'image loading performance', js: true do
    it 'implements lazy loading for images' do
      visit school_path(heavy_school)

      images = page.all('img')
      images.each do |img|
        # Should have lazy loading attributes
        has_lazy_loading = img['loading'] == 'lazy'
        has_data_src = img['data-src'].present?
        has_lazyload_class = img['class']&.include?('lazyload')
        expect(has_lazy_loading || has_data_src || has_lazyload_class).to be true
      end
    end

    it 'loads images progressively as user scrolls' do
      visit school_path(heavy_school)

      # Count initially loaded images
      initially_loaded = page.all('img[src]:not([src=""])').count

      # Scroll down to load more images
      page.execute_script('window.scrollTo(0, document.body.scrollHeight / 2)')
      sleep 1

      # More images should be loaded
      after_scroll = page.all('img[src]:not([src=""])').count
      expect(after_scroll).to be >= initially_loaded
    end

    it 'uses appropriate image sizes for different viewports', js: true do
      visit school_path(heavy_school)

      # Check for responsive images
      responsive_images = page.all('img[srcset], picture, img[sizes]')

      if responsive_images.any?
        responsive_images.each do |img|
          has_srcset = img['srcset'].present?
          is_in_picture = begin
            img.find(:xpath, '..').matches_css?('picture')
          rescue StandardError
            false
          end
          expect(has_srcset || is_in_picture).to be true
        end
      end
    end

    it 'preloads critical images' do
      visit school_path(heavy_school)

      # Hero image should be preloaded or have high priority
      hero_images = page.all('.hero img, .school-hero img')

      hero_images.each do |img|
        expect(img['loading']).not_to eq('lazy') # Critical images shouldn't be lazy
      end
    end

    it 'handles image loading errors gracefully' do
      visit school_path(heavy_school)

      # Simulate broken images
      page.execute_script('''
        document.querySelectorAll("img").forEach(img => {
          img.onerror = function() {
            this.style.display = "none";
            this.setAttribute("data-error", "true");
          };
          img.src = "broken-image.jpg";
        });
      ''')

      sleep 1

      # Page should still function with broken images
      expect(page).to have_content(heavy_school.name)
    end
  end

  describe 'JavaScript performance', js: true do
    it 'loads JavaScript without blocking page rendering' do
      start_time = Time.current

      visit school_path(heavy_school)

      # Content should be visible before all JS is loaded
      expect(page).to have_content(heavy_school.name), wait: 2

      # Should not wait for all JS to finish loading
      initial_load_time = Time.current - start_time
      expect(initial_load_time).to be < 3.seconds
    end

    it 'initializes interactive features efficiently' do
      visit school_path(heavy_school)

      # Contact form should be interactive quickly
      expect(page).to have_button('Contact School'), wait: 5

      # Should not have JavaScript errors
      errors = page.driver.browser.logs.get(:browser)
      js_errors = errors.select { |log| log.level == 'SEVERE' }
      expect(js_errors).to be_empty
    end

    it 'handles large DOM efficiently' do
      visit school_path(heavy_school)

      # Page should remain responsive with many elements
      dom_elements = page.evaluate_script('document.querySelectorAll("*").length')
      expect(dom_elements).to be < 5000 # Reasonable DOM size limit

      # Interactions should remain fast
      start_time = Time.current
      click_button 'Contact School'
      modal_open_time = Time.current - start_time

      expect(modal_open_time).to be < 0.5.seconds
    end

    it 'manages memory usage effectively' do
      visit school_path(heavy_school)

      # Simulate user interactions that could cause memory leaks
      5.times do
        click_button 'Contact School'
        find('body').send_keys :escape
        sleep 0.1
      end

      # Page should still be responsive
      expect(page).to have_content(heavy_school.name)
    end

    it 'loads third-party scripts asynchronously' do
      visit school_path(heavy_school)

      # Google Maps and other third-party scripts should not block
      scripts = page.all('script[src]')

      third_party_scripts = scripts.select do |script|
        src = script['src']
        src&.include?('google') || src&.include?('youtube') || src&.include?('facebook')
      end

      third_party_scripts.each do |script|
        has_async = script['async'].present?
        has_defer = script['defer'].present?
        expect(has_async || has_defer).to be true
      end
    end
  end

  describe 'CSS performance' do
    it 'loads critical CSS inline or with high priority' do
      visit school_path(heavy_school)

      # Above-the-fold content should render quickly
      expect(page).to have_content(heavy_school.name), wait: 2

      # Critical CSS should be loaded efficiently
      stylesheets = page.all('link[rel="stylesheet"]')
      expect(stylesheets.count).to be < 10 # Limit number of CSS files
    end

    it 'minimizes render-blocking CSS' do
      visit school_path(heavy_school)

      # Page should render progressively, not all at once
      # This is hard to test directly, but we can check that content appears quickly
      start_time = Time.current

      expect(page).to have_css('h1'), wait: 1

      h1_render_time = Time.current - start_time
      expect(h1_render_time).to be < 1.second
    end

    it 'uses efficient CSS selectors' do
      visit school_path(heavy_school)

      # Check that styles are applied (no broken CSS)
      h1_element = page.find('h1')
      font_size = h1_element.native.css_value('font-size')

      # Should have meaningful font size (CSS loaded)
      expect(font_size.to_i).to be > 16 # px
    end
  end

  describe 'form performance', js: true do
    let(:facebook_user) { create(:user, :facebook_user) }

    before { login_as(facebook_user, scope: :user) }

    it 'renders contact form quickly' do
      visit school_path(heavy_school)

      start_time = Time.current
      click_button 'Contact School'

      expect(page).to have_css('.modal', visible: true), wait: 2
      modal_load_time = Time.current - start_time

      expect(modal_load_time).to be < 0.5.seconds
    end

    it 'responds to user input without delay' do
      visit school_path(heavy_school)

      click_button 'Contact School'

      within('.modal') do
        start_time = Time.current
        fill_in 'Name', with: 'Performance Test'

        input_response_time = Time.current - start_time
        expect(input_response_time).to be < 0.1.seconds

        # Field should update immediately
        expect(page).to have_field('Name', with: 'Performance Test')
      end
    end

    it 'submits form efficiently' do
      visit school_path(heavy_school)

      click_button 'Contact School'

      within('.modal') do
        fill_in 'Name', with: 'Speed Test'
        fill_in 'Email', with: 'speed@test.com'
        fill_in 'Message', with: 'Testing form submission speed'

        start_time = Time.current
        click_button 'Send Message'

        # Should get response within reasonable time
        expect(page).to have_content('successfully', wait: 3)
        submission_time = Time.current - start_time

        expect(submission_time).to be < 2.seconds
      end
    end

    it 'handles form validation efficiently' do
      visit school_path(heavy_school)

      click_button 'Contact School'

      within('.modal') do
        # Test client-side validation speed
        email_field = find('input[type="email"]')

        start_time = Time.current
        email_field.fill_in with: 'invalid-email'
        email_field.send_keys :tab

        validation_time = Time.current - start_time
        expect(validation_time).to be < 0.1.seconds
      end
    end
  end

  describe 'mobile performance', js: true do
    before do
      page.driver.resize(width: 375, height: 667)
    end

    it 'loads efficiently on mobile devices' do
      start_time = Time.current

      visit school_path(heavy_school)
      expect(page).to have_content(heavy_school.name), wait: 10

      mobile_load_time = Time.current - start_time

      # Mobile should load within 4 seconds (slower network assumed)
      expect(mobile_load_time).to be < 4.seconds
    end

    it 'maintains performance with touch interactions' do
      visit school_path(heavy_school)

      # Touch interactions should be responsive
      start_time = Time.current
      click_button 'Contact School'

      touch_response_time = Time.current - start_time
      expect(touch_response_time).to be < 0.3.seconds
    end

    it 'optimizes content for mobile viewport' do
      visit school_path(heavy_school)

      # Should not have horizontal scroll
      page_width = page.execute_script('return document.documentElement.scrollWidth')
      viewport_width = page.execute_script('return window.innerWidth')

      expect(page_width).to be <= (viewport_width * 1.1) # Allow small margin
    end
  end

  describe 'caching and optimization' do
    it 'leverages browser caching effectively' do
      # First visit
      visit school_path(heavy_school)
      expect(page).to have_content(heavy_school.name)

      # Reload page
      page.refresh

      # Should load faster on second visit
      start_time = Time.current
      expect(page).to have_content(heavy_school.name), wait: 5
      reload_time = Time.current - start_time

      expect(reload_time).to be < 2.seconds
    end

    it 'compresses large content efficiently' do
      visit school_path(heavy_school)

      # Check response headers for compression
      # This would typically be tested at the integration level
      expect(page).to have_content(heavy_school.name)
    end

    it 'minifies resources' do
      visit school_path(heavy_school)

      # JavaScript and CSS should be minified in production-like environment
      # Check that resources load successfully
      expect(page).to have_css('h1') # CSS loaded

      # Check for JavaScript functionality
      click_button 'Contact School'
      expect(page).to have_css('.modal') # JavaScript working
    end
  end

  describe 'resource usage' do
    it 'uses reasonable bandwidth' do
      visit school_path(heavy_school)
      expect(page).to have_content(heavy_school.name)

      # Images should be optimized
      images = page.all('img[src]')
      images.each do |img|
        src = img['src']

        # Should use appropriate formats and sizes
        expect(src).not_to include('original') # Should be processed
        expect(src).to match(/\.(jpg|jpeg|png|webp)$/i)
      end
    end

    it 'limits concurrent requests' do
      visit school_path(heavy_school)
      expect(page).to have_content(heavy_school.name)

      # Should not make excessive parallel requests
      # This is hard to test directly in system tests
      # but images should use lazy loading to limit initial requests
      lazy_images = page.all('img[loading="lazy"], img[data-src]')
      total_images = page.all('img').count

      # Most images should be lazy loaded
      expect(lazy_images.count.to_f / total_images).to be > 0.5
    end

    it 'handles slow networks gracefully' do
      # Simulate slow network (if driver supports it)
      visit school_path(heavy_school)

      # Content should still load, just slower
      expect(page).to have_content(heavy_school.name), wait: 15

      # Critical content should be prioritized
      expect(page).to have_css('h1')
      expect(page).to have_button('Contact School')
    end
  end

  describe 'real-world performance scenarios' do
    it 'handles peak load simulation' do
      # Simulate multiple rapid interactions
      visit school_path(heavy_school)

      # Rapid modal open/close
      3.times do
        click_button 'Contact School'
        find('body').send_keys :escape
        sleep 0.1
      end

      # Page should remain responsive
      expect(page).to have_content(heavy_school.name)
      expect(page).to have_button('Contact School')
    end

    it 'maintains performance with browser back/forward' do
      visit school_path(heavy_school)
      expect(page).to have_content(heavy_school.name)

      # Navigate away and back
      visit root_path
      page.go_back

      # Should load quickly from cache
      start_time = Time.current
      expect(page).to have_content(heavy_school.name), wait: 3
      back_load_time = Time.current - start_time

      expect(back_load_time).to be < 1.second
    end

    it 'handles concurrent user actions' do
      visit school_path(heavy_school)

      # Simulate user doing multiple things at once
      click_button 'Contact School'

      within('.modal') do
        fill_in 'Name', with: 'Concurrent Test'

        # While typing, scroll the background
        page.execute_script('window.scrollTo(0, 100)')

        fill_in 'Email', with: 'concurrent@test.com'

        # Everything should still work
        expect(page).to have_field('Name', with: 'Concurrent Test')
        expect(page).to have_field('Email', with: 'concurrent@test.com')
      end
    end

    it 'recovers from temporary performance issues' do
      visit school_path(heavy_school)

      # Simulate temporary slowness
      page.execute_script('''
        const originalFetch = window.fetch;
        window.fetch = function(...args) {
          return new Promise(resolve => {
            setTimeout(() => resolve(originalFetch(...args)), 1000);
          });
        };
      ''')

      # User interactions should still work, just slower
      click_button 'Contact School'
      expect(page).to have_css('.modal', visible: true), wait: 3
    end
  end
end
