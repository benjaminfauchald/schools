require 'rails_helper'

RSpec.describe 'School Contact Modal', type: :system do
  let(:place) { create(:place, lat: 13.7563, lng: 100.5018) }
  let(:school) { create(:school, name: 'Test International School', place: place) }
  let(:facebook_user) { create(:user, :facebook_user, email: 'user@facebook.com') }
  let(:regular_user) { create(:user, provider: nil) }

  before do
    # Set location cookie to bypass onboarding (Cuprite driver)
    visit '/' # Need to visit a page first to set cookies
    page.driver.browser.cookies.set({
      name: 'home_location',
      value: '{"lat":13.7563,"lng":100.5018}'
    })
  end

  describe 'modal opening and closing', js: true do
    it 'opens modal when contact button is clicked' do
      visit school_path(school)

      # Find and click contact/inquiry button
      click_button 'Contact School', wait: 10

      expect(page).to have_css('.modal, [data-school-contact-modal-target="modal"]', visible: true)
      expect(page).to have_content("Contact #{school.name}")
    end

    it 'closes modal when close button is clicked' do
      visit school_path(school)

      click_button 'Contact School'
      expect(page).to have_css('.modal', visible: true)

      # Click the X close button
      find('[data-action*="closeModal"], .close-button', wait: 5).click

      expect(page).to have_css('.modal', visible: false)
    end

    it 'closes modal when clicking outside' do
      visit school_path(school)

      click_button 'Contact School'
      expect(page).to have_css('.modal', visible: true)

      # Click on backdrop/overlay
      find('.modal-backdrop, [data-action*="closeModal"]').click

      expect(page).to have_css('.modal', visible: false)
    end

    it 'closes modal with Escape key' do
      visit school_path(school)

      click_button 'Contact School'
      expect(page).to have_css('.modal', visible: true)

      # Press Escape key
      find('body').send_keys :escape

      expect(page).to have_css('.modal', visible: false)
    end

    it 'maintains modal state during form interaction' do
      visit school_path(school)

      click_button 'Contact School'
      expect(page).to have_css('.modal', visible: true)

      # Interact with form
      fill_in 'Name', with: 'Test User'
      fill_in 'Email', with: 'test@example.com'

      # Modal should remain open
      expect(page).to have_css('.modal', visible: true)
      expect(page).to have_field('Name', with: 'Test User')
    end
  end

  describe 'modal content for non-authenticated users' do
    it 'displays Facebook authentication requirement' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        expect(page).to have_content('sign in with Facebook')
        expect(page).to have_content('verify genuine inquiries')
        expect(page).to have_button('Continue with Facebook')
      end
    end

    it 'shows explanation about Facebook requirement' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        expect(page).to have_content('quality inquiries')
        expect(page).to have_content('protect schools from spam')
      end
    end

    it 'displays contact form fields' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal form') do
        expect(page).to have_field('Name', type: 'text')
        expect(page).to have_field('Email', type: 'email')
        expect(page).to have_field('Phone')
        expect(page).to have_field('children_count', type: 'number')
        expect(page).to have_field('Message', type: 'textarea')
      end
    end

    it 'sets default values correctly' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        expect(page).to have_field('children_count', with: '1')
        expect(page).to have_field('Message', placeholder: /interested in enrolling/)
      end
    end

    it 'shows Facebook authentication button instead of submit' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        expect(page).to have_button('Continue with Facebook')
        expect(page).not_to have_button('Send Message')
      end
    end
  end

  describe 'modal content for regular authenticated users' do
    before { login_as(regular_user, scope: :user) }

    it 'still requires Facebook authentication' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        expect(page).to have_content('sign in with Facebook')
        expect(page).to have_button('Continue with Facebook')
        expect(page).not_to have_button('Send Message')
      end
    end

    it 'shows authentication message for signed-in non-Facebook user' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        expect(page).to have_content('Please sign in with Facebook')
      end
    end
  end

  describe 'modal content for Facebook authenticated users' do
    before { login_as(facebook_user, scope: :user) }

    it 'shows direct submit form' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        expect(page).to have_button('Send Message')
        expect(page).not_to have_button('Continue with Facebook')
      end
    end

    it 'displays encouraging message' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        expect(page).to have_content("Send a message to #{school.name}")
        expect(page).to have_content("they'll get back to you soon")
      end
    end

    it 'does not show Facebook authentication requirement' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        expect(page).not_to have_content('sign in with Facebook')
        expect(page).not_to have_content('verify genuine inquiries')
      end
    end
  end

  describe 'form validation and submission', js: true do
    before { login_as(facebook_user, scope: :user) }

    it 'validates required fields' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        click_button 'Send Message'

        # HTML5 validation should prevent submission
        expect(page).to have_css('input:invalid, textarea:invalid')
      end
    end

    it 'validates email format' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        fill_in 'Name', with: 'Test User'
        fill_in 'Email', with: 'invalid-email'
        fill_in 'Message', with: 'Test message'

        click_button 'Send Message'

        # Should show validation error
        expect(page).to have_css('input[type="email"]:invalid')
      end
    end

    it 'submits form successfully with valid data', :aggregate_failures do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        fill_in 'Name', with: 'John Doe'
        fill_in 'Email', with: 'john.doe@example.com'
        fill_in 'Phone', with: '+66 2 123 4567'
        fill_in 'children_count', with: '2'
        fill_in 'Message', with: 'I am very interested in enrolling my children at your school.'

        # Mock the successful AJAX response
        expect {
          click_button 'Send Message'
          sleep 2 # Allow AJAX to complete
        }.to change { SchoolInquiry.count }.by(1)
      end
    end

    it 'shows success message after submission' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        fill_in 'Name', with: 'Jane Smith'
        fill_in 'Email', with: 'jane.smith@example.com'
        fill_in 'Message', with: 'Please provide more information about your programs.'

        click_button 'Send Message'
      end

      # Should show success feedback
      expect(page).to have_content('sent successfully', wait: 5)
    end

    it 'handles form submission errors gracefully' do
      visit school_path(school)

      # Mock server error
      allow_any_instance_of(SchoolInquiriesController).to receive(:create)
        .and_raise(StandardError.new('Server error'))

      click_button 'Contact School'

      within('.modal') do
        fill_in 'Name', with: 'Test User'
        fill_in 'Email', with: 'test@example.com'
        fill_in 'Message', with: 'Test message'

        click_button 'Send Message'
      end

      expect(page).to have_content('error', wait: 5)
    end

    it 'prevents double submission' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        fill_in 'Name', with: 'Test User'
        fill_in 'Email', with: 'test@example.com'
        fill_in 'Message', with: 'Test message'

        submit_button = find('input[type="submit"], button[type="submit"]')
        submit_button.click

        # Button should be disabled to prevent double submission
        expect(submit_button).to be_disabled
      end
    end
  end

  describe 'Facebook authentication flow', js: true do
    context 'when user needs Facebook authentication' do
      it 'initiates Facebook OAuth when button clicked' do
        visit school_path(school)

        click_button 'Contact School'

        within('.modal') do
          # Fill out form first
          fill_in 'Name', with: 'Test User'
          fill_in 'Email', with: 'test@example.com'
          fill_in 'Message', with: 'Test inquiry'

          # Store form data should be triggered
          expect(page).to have_button('Continue with Facebook')
        end
      end

      it 'preserves form data during authentication' do
        visit school_path(school)

        click_button 'Contact School'

        within('.modal') do
          fill_in 'Name', with: 'Preserved User'
          fill_in 'Email', with: 'preserved@example.com'
          fill_in 'Message', with: 'This should be preserved'

          # Form data should be stored before authentication
          click_button 'Continue with Facebook'
        end

        # After mock authentication, form should restore data
        # (This would require more complex setup to test fully)
      end
    end
  end

  describe 'modal accessibility', js: true do
    it 'traps focus within modal when open' do
      visit school_path(school)

      click_button 'Contact School'

      # Focus should be trapped within modal
      first_input = find('.modal input[name="name"]')
      first_input.send_keys :tab

      expect(page).to have_selector('.modal input:focus')
    end

    it 'returns focus to trigger button when closed' do
      visit school_path(school)

      contact_button = find('button', text: 'Contact School')
      contact_button.click

      find('[data-action*="closeModal"]').click

      # Focus should return to original trigger
      expect(contact_button).to match_selector(':focus')
    end

    it 'includes proper ARIA attributes' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        expect(page).to have_css('[role="dialog"], [role="modal"]')
        expect(page).to have_css('[aria-label], [aria-labelledby]')
      end
    end

    it 'supports keyboard navigation' do
      visit school_path(school)

      click_button 'Contact School'

      # Should be able to navigate with keyboard
      find('.modal input[name="name"]').send_keys :tab
      expect(find('.modal input[name="email"]')).to match_selector(':focus')
    end
  end

  describe 'mobile responsive behavior', js: true do
    before do
      page.driver.resize(width: 375, height: 667)
    end

    it 'displays modal properly on mobile' do
      visit school_path(school)

      click_button 'Contact School'

      expect(page).to have_css('.modal', visible: true)
      expect(page).to have_content("Contact #{school.name}")
    end

    it 'maintains usability on small screens' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        expect(page).to have_field('Name')
        expect(page).to have_field('Email')
        expect(page).to have_field('Message')

        # All fields should be accessible
        fill_in 'Name', with: 'Mobile User'
        expect(page).to have_field('Name', with: 'Mobile User')
      end
    end

    it 'handles modal overflow correctly' do
      visit school_path(school)

      click_button 'Contact School'

      # Modal should be scrollable if content overflows
      expect(page).to have_css('.modal [class*="overflow"], .modal [class*="scroll"]')
    end
  end

  describe 'error states and edge cases' do
    it 'handles missing school gracefully' do
      # Visit invalid school page
      visit '/schools/nonexistent'

      # Should show 404 or redirect, not crash modal
      expect(page).to have_http_status(:not_found) || have_current_path('/')
    end

    it 'handles network errors during submission', js: true do
      login_as(facebook_user, scope: :user)
      visit school_path(school)

      click_button 'Contact School'

      # Simulate network failure
      page.execute_script('''
        window.fetch = function() {
          return Promise.reject(new Error("Network error"));
        };
      ''')

      within('.modal') do
        fill_in 'Name', with: 'Test User'
        fill_in 'Email', with: 'test@example.com'
        fill_in 'Message', with: 'Test message'

        click_button 'Send Message'
      end

      expect(page).to have_content('error', wait: 5)
    end

    it 'prevents XSS in form fields' do
      login_as(facebook_user, scope: :user)
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        fill_in 'Name', with: '<script>alert("xss")</script>'
        fill_in 'Email', with: 'test@example.com'
        fill_in 'Message', with: '<img src=x onerror=alert("xss")>'

        click_button 'Send Message'
      end

      # Should handle malicious input safely
      expect(page).not_to have_content('<script>')
    end
  end

  describe 'modal header and branding' do
    it 'displays correct modal title' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal-header, .modal h3, .modal .title') do
        expect(page).to have_content("Contact #{school.name}")
      end
    end

    it 'shows school branding if available' do
      school.update(logo_url: 'https://example.com/logo.png')
      visit school_path(school)

      click_button 'Contact School'

      # Should show school logo or name prominently
      expect(page).to have_content(school.name)
    end
  end

  describe 'form field behavior' do
    before { login_as(facebook_user, scope: :user) }

    it 'auto-focuses first field when modal opens' do
      visit school_path(school)

      click_button 'Contact School'

      expect(find('.modal input[name="name"]')).to match_selector(':focus')
    end

    it 'validates children count field' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        children_field = find('input[name="children_count"]')
        expect(children_field['min']).to eq('1')
        expect(children_field['max']).to eq('20')
      end
    end

    it 'limits message length' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        message_field = find('textarea[name="message"]')
        expect(message_field['maxlength']).to eq('2000')
      end
    end

    it 'provides helpful placeholder text' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        expect(page).to have_field('Name', placeholder: 'Your full name')
        expect(page).to have_field('Email', placeholder: /example\.com/)
        expect(page).to have_field('Message', placeholder: /interested in enrolling/)
      end
    end
  end
end
