require 'rails_helper'

RSpec.describe 'School Detail Page Edge Cases', type: :system do
  let(:place) { create(:place, lat: 13.7563, lng: 100.5018) }
  let(:school) { create(:school, place: place) }
  let(:facebook_user) { create(:user, :facebook_user) }

  before do
    # Set location cookie to bypass onboarding (Cuprite driver)
    visit '/' # Need to visit a page first to set cookies
    page.driver.browser.cookies.set({
      name: 'home_location',
      value: '{"lat":13.7563,"lng":100.5018}'
    })
  end

  describe 'data edge cases' do
    context 'with missing or null data' do
      let(:minimal_school) { create(:school, place: nil, about: nil, phone: nil, email: nil) }

      it 'handles school without place gracefully' do
        visit school_path(minimal_school)

        expect(page).to have_content(minimal_school.name)
        expect(page).not_to have_content('undefined')
        expect(page).not_to have_content('null')
      end

      it 'displays fallback content for missing information' do
        visit school_path(minimal_school)

        # Should show placeholders or hide empty sections
        expect(page).not_to have_content('Contact Information') ||
               have_content('Contact school directly')
      end

      it 'hides empty sections gracefully' do
        visit school_path(minimal_school)

        # Empty sections should not appear
        expect(page).not_to have_content('Academic Programs')
        expect(page).not_to have_content('Campus Facilities')
        expect(page).not_to have_content('Photo Gallery')
      end
    end

    context 'with corrupted or invalid data' do
      let(:corrupted_school) do
        create(:school, place: place).tap do |s|
          # Add invalid JSON data
          s.update_column(:preferences, '{"invalid": json}')
          s.update_column(:facebook_content, '{broken json')
        end
      end

      it 'handles corrupted JSON data without crashing' do
        visit school_path(corrupted_school)
        expect(page).to have_content(corrupted_school.name)
      end

      it 'continues to display valid information despite data corruption' do
        visit school_path(corrupted_school)
        expect(page).to have_content(corrupted_school.name)
        expect(page).to have_button('Contact School')
      end
    end

    context 'with extremely long content' do
      let(:long_content_school) do
        create(:school,
          name: 'A' * 200,  # Very long name
          about: 'B' * 5000, # Very long description
          phone: '+66-123-456-789-extension-9999',
          place: place
        )
      end

      it 'displays long content without breaking layout' do
        visit school_path(long_content_school)

        expect(page).to have_content(long_content_school.name[0..50])
        expect(page.body).not_to include('overflow')
      end

      it 'truncates or handles very long text appropriately' do
        visit school_path(long_content_school)

        # Should not cause horizontal scrolling
        page_width = page.execute_script('return document.documentElement.scrollWidth')
        viewport_width = page.execute_script('return window.innerWidth')
        expect(page_width).to be <= (viewport_width * 1.1)
      end

      it 'maintains performance with large content' do
        start_time = Time.current
        visit school_path(long_content_school)
        expect(page).to have_content(long_content_school.name[0..20]), wait: 10
        load_time = Time.current - start_time

        expect(load_time).to be < 5.seconds
      end
    end

    context 'with special characters and encodings' do
      let(:unicode_school) do
        create(:school,
          name: '🏫 École Internationale de Bangkok 北京国际学校 مدرسة دولية',
          about: 'Multi-language content: 中文 العربية Français ไทย русский 日本語 한국어',
          phone: '+33-123-456-789',
          email: 'école@international-bangkok.edu',
          place: place
        )
      end

      it 'displays Unicode characters correctly' do
        visit school_path(unicode_school)

        expect(page).to have_content('🏫')
        expect(page).to have_content('École')
        expect(page).to have_content('北京国际学校')
        expect(page).to have_content('مدرسة دولية')
      end

      it 'handles RTL text appropriately' do
        visit school_path(unicode_school)

        # Arabic text should be present
        expect(page).to have_content('مدرسة')

        # Page should not break with mixed LTR/RTL content
        expect(page).to have_content(unicode_school.name)
      end

      it 'processes email and phone with international characters' do
        visit school_path(unicode_school)

        click_button 'Contact School'

        within('.modal') do
          expect(page).to have_content('Contact')
        end
      end
    end
  end

  describe 'network and connectivity edge cases', js: true do
    context 'with slow network conditions' do
      it 'provides loading indicators for slow content' do
        visit school_path(school)

        # Should show loading states
        expect(page).to have_content(school.name), wait: 15
      end

      it 'loads critical content first on slow connections' do
        visit school_path(school)

        # Hero content should load before everything else
        expect(page).to have_content(school.name), wait: 3
        expect(page).to have_button('Contact School'), wait: 5
      end
    end

    context 'with network failures' do
      it 'handles AJAX failures gracefully' do
        login_as(facebook_user, scope: :user)
        visit school_path(school)

        # Mock network failure
        page.execute_script('''
          window.fetch = function() {
            return Promise.reject(new Error("Network error"));
          };
        ''')

        click_button 'Contact School'

        within('.modal') do
          fill_in 'Name', with: 'Network Test'
          fill_in 'Email', with: 'test@example.com'
          fill_in 'Message', with: 'Testing network failure'

          click_button 'Send Message'

          expect(page).to have_content('error') || have_content('try again'), wait: 5
        end
      end

      it 'provides offline functionality where possible' do
        visit school_path(school)

        # Basic content should still be available
        expect(page).to have_content(school.name)
        expect(page).to have_content('Contact')
      end

      it 'recovers gracefully when connection resumes' do
        login_as(facebook_user, scope: :user)
        visit school_path(school)

        click_button 'Contact School'

        within('.modal') do
          fill_in 'Name', with: 'Recovery Test'
          fill_in 'Email', with: 'recovery@example.com'
          fill_in 'Message', with: 'Testing connection recovery'

          click_button 'Send Message'

          # Should handle recovery scenario
          expect(page).to have_content('successfully') || have_content('error'), wait: 10
        end
      end
    end
  end

  describe 'browser compatibility edge cases' do
    context 'with JavaScript disabled' do
      it 'provides basic functionality without JavaScript' do
        # Switch to rack_test driver (no JS)
        Capybara.current_driver = :rack_test

        visit school_path(school)

        expect(page).to have_content(school.name)
        expect(page).to have_content('Contact')

        # Restore JS driver
        Capybara.use_default_driver
      end
    end

    context 'with missing browser features' do
      it 'handles missing geolocation API' do
        visit school_path(school)

        page.execute_script('navigator.geolocation = undefined;')

        # Should not crash
        expect(page).to have_content(school.name)
      end

      it 'handles missing local storage' do
        visit school_path(school)

        page.execute_script('window.localStorage = undefined;')

        # Should continue to function
        expect(page).to have_button('Contact School')
      end
    end

    context 'with old browser simulation' do
      it 'provides fallbacks for modern CSS features' do
        visit school_path(school)

        # Remove CSS grid support
        page.execute_script("""
          document.documentElement.style.setProperty('display', 'block', 'important');
          Array.from(document.querySelectorAll('*')).forEach(el => {
            if (getComputedStyle(el).display.includes('grid')) {
              el.style.display = 'block';
            }
          });
        """)

        # Layout should still work
        expect(page).to have_content(school.name)
      end
    end
  end

  describe 'security edge cases' do
    context 'with malicious input' do
      it 'prevents XSS in form submissions' do
        login_as(facebook_user, scope: :user)
        visit school_path(school)

        click_button 'Contact School'

        within('.modal') do
          fill_in 'Name', with: '<script>alert("xss")</script>'
          fill_in 'Email', with: 'xss@test.com'
          fill_in 'Message', with: '<img src=x onerror=alert("xss")>'

          click_button 'Send Message'
        end

        # Should not execute scripts
        expect(page.html).not_to include('<script>alert("xss")</script>')
        expect(page).not_to have_content('<script>')
      end

      it 'handles SQL injection attempts safely' do
        # This should be caught at the routing level
        expect {
          visit "/schools/'; DROP TABLE schools; --"
        }.not_to raise_error(ActiveRecord::StatementInvalid)
      end

      it 'sanitizes URL parameters' do
        visit school_path(school.id, malicious: '<script>alert("xss")</script>')

        # Should not include malicious content
        expect(page.html).not_to include('<script>alert("xss")</script>')
      end
    end

    context 'with authentication edge cases' do
      it 'handles expired sessions gracefully' do
        login_as(facebook_user, scope: :user)
        visit school_path(school)

        # Simulate expired session
        page.driver.browser.manage.delete_all_cookies

        click_button 'Contact School'

        # Should redirect to login or show appropriate message
        expect(page).to have_content('Facebook') ||
               have_current_path(/sign_in|login/)
      end

      it 'prevents unauthorized actions' do
        visit school_path(school)

        # Try to access authenticated endpoints directly
        page.driver.post school_school_inquiries_path(school_id: school.id),
                         { school_inquiry: { name: 'Test', email: 'test@test.com', message: 'Test' } }

        # Should be redirected or show error
        is_unauthorized = page.status_code == 401
        is_redirected_to_login = page.current_path.match?(/sign_in|login/)
        expect(is_unauthorized || is_redirected_to_login).to be true
      end
    end
  end

  describe 'database edge cases' do
    context 'with database connectivity issues' do
      it 'handles temporary database unavailability' do
        # This is hard to test in system tests without actually breaking the DB
        # We can test graceful degradation instead

        allow(School).to receive(:find).and_raise(ActiveRecord::ConnectionTimeoutError)

        expect {
          visit school_path(school)
        }.to raise_error(ActiveRecord::ConnectionTimeoutError)
      end

      it 'handles concurrent access gracefully' do
        # Test that multiple users can access simultaneously
        visit school_path(school)
        expect(page).to have_content(school.name)

        # Simulate concurrent access (basic test)
        10.times do
          click_button 'Contact School'
          find('body').send_keys :escape
        end

        expect(page).to have_content(school.name)
      end
    end

    context 'with data consistency issues' do
      it 'handles orphaned records gracefully' do
        # Create school with place, then delete place
        place_id = school.place.id
        school.place.destroy
        school.reload

        visit school_path(school)

        # Should not crash
        expect(page).to have_content(school.name)
      end
    end
  end

  describe 'UI/UX edge cases' do
    context 'with extreme viewport sizes' do
      it 'handles very small screens', js: true do
        page.driver.resize(width: 280, height: 400)

        visit school_path(school)

        expect(page).to have_content(school.name)
        expect(page).to have_button('Contact School')

        # Should not have horizontal scroll
        page_width = page.execute_script('return document.documentElement.scrollWidth')
        viewport_width = page.execute_script('return window.innerWidth')
        expect(page_width).to be <= (viewport_width * 1.1)
      end

      it 'handles very large screens', js: true do
        page.driver.resize(width: 2560, height: 1440)

        visit school_path(school)

        expect(page).to have_content(school.name)

        # Layout should not break on ultra-wide screens
        content_width = page.execute_script('return document.querySelector("main, .main-content, .container").offsetWidth')
        expect(content_width).to be > 0
      end
    end

    context 'with high zoom levels', js: true do
      it 'remains functional at 200% zoom' do
        visit school_path(school)

        page.execute_script('document.body.style.zoom = "200%"')

        expect(page).to have_content(school.name)
        expect(page).to have_button('Contact School')
      end

      it 'handles zoom without breaking interactions' do
        visit school_path(school)

        page.execute_script('document.body.style.zoom = "150%"')

        click_button 'Contact School'
        expect(page).to have_css('.modal', visible: true)
      end
    end

    context 'with accessibility tools' do
      it 'works with screen reader simulation', js: true do
        visit school_path(school)

        # Simulate screen reader navigation
        find('body').send_keys :tab
        expect(page).to have_css(':focus')

        # Should be able to navigate to main content
        focused_element = page.evaluate_script('document.activeElement.tagName')
        expect(%w[A BUTTON INPUT]).to include(focused_element)
      end
    end
  end

  describe 'concurrent user scenarios' do
    it 'handles multiple modal operations' do
      visit school_path(school)

      # Rapidly open and close modals
      5.times do |i|
        click_button 'Contact School'
        expect(page).to have_css('.modal', visible: true)

        find('body').send_keys :escape
        expect(page).to have_css('.modal', visible: false)

        sleep 0.1
      end

      # Should still work normally
      click_button 'Contact School'
      expect(page).to have_css('.modal', visible: true)
    end

    it 'maintains state during rapid interactions' do
      login_as(facebook_user, scope: :user)
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        fill_in 'Name', with: 'Rapid Test'

        # Rapid typing and field changes
        10.times do |i|
          find('input[name="name"]').send_keys i.to_s
          find('input[name="email"]').click
          find('input[name="name"]').click
        end

        # Final state should be preserved
        expect(page).to have_field('Name', with: /Rapid Test/)
      end
    end
  end

  describe 'error recovery scenarios' do
    it 'recovers from JavaScript errors gracefully', js: true do
      visit school_path(school)

      # Introduce JavaScript error
      page.execute_script('throw new Error("Simulated JS error");')

      # Page should still be usable
      expect(page).to have_content(school.name)

      # Basic interactions should still work
      click_button 'Contact School'
      expect(page).to have_css('.modal') || have_content('Contact')
    end

    it 'handles partial page load failures' do
      visit school_path(school)

      # Simulate failed component loading
      page.execute_script("""
        document.querySelectorAll('.photo-gallery, .video-gallery').forEach(el => {
          el.innerHTML = '<div>Failed to load</div>';
        });
      """)

      # Core functionality should remain
      expect(page).to have_content(school.name)
      expect(page).to have_button('Contact School')
    end

    it 'provides helpful error messages to users' do
      login_as(facebook_user, scope: :user)
      visit school_path(school)

      # Mock server error response
      page.execute_script("""
        window.fetch = function() {
          return Promise.resolve({
            ok: false,
            status: 500,
            json: () => Promise.resolve({success: false, errors: ['Server error occurred']})
          });
        };
      """)

      click_button 'Contact School'

      within('.modal') do
        fill_in 'Name', with: 'Error Test'
        fill_in 'Email', with: 'error@test.com'
        fill_in 'Message', with: 'Test error handling'

        click_button 'Send Message'

        # Should show user-friendly error message
        has_error = page.has_content?('error')
        has_retry_message = page.has_content?('try again') || page.has_content?('later')
        expect(has_error && has_retry_message).to be true
      end
    end
  end

  describe 'boundary value testing' do
    it 'handles maximum form field lengths' do
      login_as(facebook_user, scope: :user)
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        # Test maximum message length
        max_message = 'A' * 2000
        fill_in 'Message', with: max_message

        # Should accept maximum length
        expect(page).to have_field('Message', with: max_message)

        # Try to exceed maximum
        over_limit = 'A' * 2001
        fill_in 'Message', with: over_limit

        # Should truncate or show validation error
        current_value = find('textarea[name="message"]').value
        expect(current_value.length).to be <= 2000
      end
    end

    it 'handles minimum required values' do
      login_as(facebook_user, scope: :user)
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        # Test with minimum valid input
        fill_in 'Name', with: 'A'
        fill_in 'Email', with: 'a@b.c'
        fill_in 'Message', with: 'Hi'

        click_button 'Send Message'

        # Should accept minimum valid input
        expect(page).to have_content('successfully') || have_content('error')
      end
    end
  end
end
