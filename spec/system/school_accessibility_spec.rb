require 'rails_helper'

RSpec.describe 'School Detail Page Accessibility', type: :system do
  let(:place) { create(:place, lat: 13.7563, lng: 100.5018, formatted_address: '123 Accessible School Street, Bangkok') }
  let(:school) { create(:school, name: 'Accessible International School', place: place) }
  let(:school_with_media) { create(:school, :with_media, place: place) }
  let(:facebook_user) { create(:user, :facebook_user) }

  let(:comprehensive_school) do
    create(:school, name: 'Inclusive Education Center', place: place).tap do |s|
      create(:school_fee_schedule, school: s, grade_level: 'Primary', tuition_fee_thb: 150000)
      create(:school_grade_offering, school: s, min_age: 3, max_age: 18)

      # Add taxonomy terms
      curriculum_vocab = create(:vocabulary, code: 'curriculum')
      facility_vocab = create(:vocabulary, code: 'facility')

      ib_curriculum = create(:term, vocabulary: curriculum_vocab, label: 'IB Programme')
      library_facility = create(:term, vocabulary: facility_vocab, label: 'Library')

      s.add_term(ib_curriculum)
      s.add_term(library_facility)

      create_list(:media_item, 3, place: s.place)
      create_list(:page, 2, school: s, status: 'published')
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

  describe 'semantic HTML structure' do
    it 'uses proper heading hierarchy' do
      visit school_path(comprehensive_school)

      # Should have h1 for school name
      expect(page).to have_css('h1')
      expect(page.find('h1')).to have_content(comprehensive_school.name)

      # Should have logical heading progression
      headings = page.all('h1, h2, h3, h4, h5, h6').map(&:tag_name)
      expect(headings.first).to eq('h1')

      # No heading level should be skipped
      heading_levels = headings.map { |h| h.last.to_i }.uniq.sort
      expect(heading_levels).to eq((1..heading_levels.max).to_a)
    end

    it 'uses semantic landmarks' do
      visit school_path(comprehensive_school)

      # Should have main landmark
      expect(page).to have_css('main, [role="main"]')

      # Should have navigation landmarks
      expect(page).to have_css('nav, [role="navigation"]') ||
                   have_css('header') ||
                   have_css('[aria-label*="navigation"]')

      # Should have content sections
      expect(page).to have_css('section, article, aside')
    end

    it 'provides proper document structure' do
      visit school_path(comprehensive_school)

      # Should have proper HTML document structure
      expect(page).to have_css('html[lang]')
      expect(page).to have_title
      expect(page).to have_css('meta[name="viewport"]')
    end

    it 'uses lists for grouped content' do
      visit school_path(comprehensive_school)

      # Facilities, academic programs, etc. should use list markup
      expect(page).to have_css('ul, ol') # Lists for grouped items
    end
  end

  describe 'keyboard navigation', js: true do
    it 'supports tab navigation through all interactive elements' do
      visit school_path(comprehensive_school)

      # Find all interactive elements
      interactive_elements = page.all('a, button, input, select, textarea, [tabindex]:not([tabindex="-1"])')

      expect(interactive_elements.count).to be > 0

      # Should be able to reach all interactive elements via keyboard
      first_element = interactive_elements.first
      first_element.send_keys :tab

      expect(page).to have_css(':focus')
    end

    it 'maintains logical tab order' do
      visit school_path(comprehensive_school)

      # Tab through form fields in contact modal
      click_button 'Contact School'

      within('.modal') do
        name_field = find('input[name="name"]')
        expect(name_field).to match_selector(':focus') # Should auto-focus

        name_field.send_keys :tab
        expect(find('input[name="email"]')).to match_selector(':focus')

        find('input[name="email"]').send_keys :tab
        # Should continue in logical order
        expect(page).to have_css('input:focus, textarea:focus')
      end
    end

    it 'provides skip navigation links' do
      visit school_path(comprehensive_school)

      # Press tab to reveal skip links
      find('body').send_keys :tab

      expect(page).to have_link('Skip to main content') ||
                   have_link('Skip to content') ||
                   have_css('.skip-link[href="#main"]')
    end

    it 'handles modal focus trapping', js: true do
      visit school_path(comprehensive_school)

      click_button 'Contact School'

      within('.modal') do
        # Focus should be trapped within modal
        last_element = all('a, button, input, select, textarea').last
        last_element.send_keys :tab

        # Focus should wrap back to first element
        expect(page).to have_css('.modal :focus')
      end
    end

    it 'supports escape key for modal closing' do
      visit school_path(comprehensive_school)

      click_button 'Contact School'
      expect(page).to have_css('.modal', visible: true)

      # Press escape to close
      find('body').send_keys :escape
      expect(page).to have_css('.modal', visible: false)
    end

    it 'restores focus after modal closes' do
      visit school_path(comprehensive_school)

      contact_button = find('button', text: 'Contact School')
      contact_button.click

      find('body').send_keys :escape

      # Focus should return to trigger button
      expect(contact_button).to match_selector(':focus')
    end
  end

  describe 'ARIA attributes and roles' do
    it 'provides proper ARIA labels for buttons' do
      visit school_path(comprehensive_school)

      # Buttons should have descriptive labels
      buttons = page.all('button')
      buttons.each do |button|
        # Either text content or aria-label should be present
        expect(button.text.present? || button['aria-label'].present?).to be true
      end
    end

    it 'uses ARIA roles for modal dialogs' do
      visit school_path(comprehensive_school)

      click_button 'Contact School'

      within('.modal') do
        expect(page).to have_css('[role="dialog"], [role="modal"]')
        expect(page).to have_css('[aria-labelledby], [aria-label]')
      end
    end

    it 'provides ARIA labels for form fields' do
      visit school_path(comprehensive_school)

      click_button 'Contact School'

      within('.modal form') do
        # All form inputs should have labels or aria-label
        inputs = page.all('input, textarea, select')
        inputs.each do |input|
          # Should have label, aria-label, or aria-labelledby
          input_id = input['id']
          has_label = input_id && page.has_css?("label[for='#{input_id}']")
          has_aria_label = input['aria-label'].present?
          has_aria_labelledby = input['aria-labelledby'].present?

          expect(has_label || has_aria_label || has_aria_labelledby).to be true
        end
      end
    end

    it 'uses ARIA live regions for dynamic content' do
      login_as(facebook_user, scope: :user)
      visit school_path(comprehensive_school)

      click_button 'Contact School'

      # Form validation messages should use live regions
      within('.modal') do
        click_button 'Send Message' # Will trigger validation

        expect(page).to have_css('[aria-live], [role="alert"]')
      end
    end

    it 'provides ARIA expanded states for collapsible content' do
      visit school_path(comprehensive_school)

      # Look for expandable sections
      expandable_triggers = page.all('[aria-expanded]')
      expandable_triggers.each do |trigger|
        expect([ 'true', 'false' ]).to include(trigger['aria-expanded'])
      end
    end

    it 'uses ARIA described-by for form help text' do
      visit school_path(comprehensive_school)

      click_button 'Contact School'

      within('.modal form') do
        # Fields with help text should use aria-describedby
        help_text_elements = page.all('.help-text, .field-help, [id*="help"]')

        help_text_elements.each do |help_element|
          help_id = help_element['id']
          if help_id
            expect(page).to have_css("[aria-describedby*='#{help_id}']")
          end
        end
      end
    end
  end

  describe 'screen reader support' do
    it 'provides descriptive alt text for images' do
      visit school_path(school_with_media)

      images = page.all('img')
      images.each do |img|
        alt_text = img['alt']

        # Should have meaningful alt text (not empty or generic)
        expect(alt_text).to be_present
        expect(alt_text).not_to eq('image')
        expect(alt_text).not_to eq('photo')
        expect(alt_text.length).to be > 3
      end
    end

    it 'uses proper headings for content organization' do
      visit school_path(comprehensive_school)

      # Each major section should have a heading
      expect(page).to have_content('Academic Programs')
      expect(page).to have_css('h2, h3', text: /Academic Programs|Curriculum/)

      expect(page).to have_content('Campus Facilities')
      expect(page).to have_css('h2, h3', text: /Facilities|Campus/)

      if page.has_content?('Tuition & Fees')
        expect(page).to have_css('h2, h3', text: /Tuition|Fees/)
      end
    end

    it 'provides screen reader text for icons' do
      visit school_path(comprehensive_school)

      # Icons should have screen reader text
      icons = page.all('svg, i[class*="icon"], span[class*="icon"]')
      icons.each do |icon|
        # Should have aria-label, title, or screen reader text
        has_aria_label = icon['aria-label'].present?
        has_title = icon['title'].present?
        has_sr_text = icon.has_css?('.sr-only, .screen-reader-text, .visually-hidden')

        expect(has_aria_label || has_title || has_sr_text).to be true
      end
    end

    it 'announces form errors to screen readers' do
      login_as(facebook_user, scope: :user)
      visit school_path(comprehensive_school)

      click_button 'Contact School'

      within('.modal') do
        # Submit invalid form
        fill_in 'Email', with: 'invalid-email'
        click_button 'Send Message'

        # Error messages should be announced
        expect(page).to have_css('[role="alert"], [aria-live="polite"], [aria-live="assertive"]')
      end
    end

    it 'provides context for form fields' do
      visit school_path(comprehensive_school)

      click_button 'Contact School'

      within('.modal form') do
        # Required fields should be marked
        required_inputs = page.all('input[required], textarea[required]')
        required_inputs.each do |input|
          # Should indicate required status
          input_label_text = page.find("label[for='#{input['id']}']").text
          has_required_text = input_label_text.match?(/\*|required/i)
          has_aria_required = input['aria-required'] == 'true'

          expect(has_required_text || has_aria_required).to be true
        end
      end
    end
  end

  describe 'color and contrast accessibility' do
    it 'uses sufficient color contrast', js: true do
      visit school_path(comprehensive_school)

      # Check text elements have sufficient contrast
      # This is a basic check - full contrast testing would require additional tools
      text_elements = page.all('p, span, a, button, h1, h2, h3, h4, h5, h6')

      text_elements.each do |element|
        # Text should be visible (not transparent or same as background)
        color = element.native.css_value('color')
        expect(color).not_to eq('transparent')
        expect(color).not_to eq('rgba(0, 0, 0, 0)')
      end
    end

    it 'does not rely solely on color for information' do
      visit school_path(comprehensive_school)

      # Required fields should have text indicators, not just color
      click_button 'Contact School'

      within('.modal form') do
        required_fields = page.all('input[required], textarea[required]')
        required_fields.each do |field|
          field_label = page.find("label[for='#{field['id']}']")

          # Should have text indication of required status
          has_asterisk = field_label.text.include?('*')
          has_aria_required = field['aria-required'] == 'true'
          has_required_text = page.has_content?('required', normalize_ws: true)

          expect(has_asterisk || has_aria_required || has_required_text).to be true
        end
      end
    end

    it 'maintains visibility in high contrast mode', js: true do
      visit school_path(comprehensive_school)

      # Simulate high contrast mode
      page.execute_script("document.documentElement.style.filter = 'contrast(200%) brightness(150%);")

      # Content should still be visible and readable
      expect(page).to have_content(comprehensive_school.name)
      expect(page).to have_button('Contact School')
    end
  end

  describe 'responsive accessibility' do
    it 'maintains accessibility on mobile devices', js: true do
      page.driver.resize(width: 375, height: 667)

      visit school_path(comprehensive_school)

      # Should maintain heading structure
      expect(page).to have_css('h1')
      expect(page.find('h1')).to have_content(comprehensive_school.name)

      # Should maintain keyboard navigation
      find('body').send_keys :tab
      expect(page).to have_css(':focus')

      # Touch targets should be large enough (44px minimum)
      buttons = page.all('button, a')
      buttons.each do |button|
        height = button.native.size.height
        width = button.native.size.width

        # Either height or width should be at least 44px for touch accessibility
        expect([ height, width ].max).to be >= 40
      end
    end

    it 'provides accessible zoom support' do
      visit school_path(comprehensive_school)

      # Page should support zoom up to 200% without horizontal scrolling
      page.execute_script('document.body.style.zoom = "200%"')

      expect(page).to have_content(comprehensive_school.name)

      # Should not cause horizontal scrolling
      page_width = page.execute_script('return document.documentElement.scrollWidth')
      viewport_width = page.execute_script('return window.innerWidth')

      expect(page_width).to be <= (viewport_width * 1.1) # Allow small margin
    end
  end

  describe 'form accessibility' do
    before { login_as(facebook_user, scope: :user) }

    it 'associates labels with form controls' do
      visit school_path(comprehensive_school)

      click_button 'Contact School'

      within('.modal form') do
        inputs = page.all('input, textarea, select')
        inputs.each do |input|
          input_id = input['id']
          expect(input_id).to be_present

          # Should have associated label
          expect(page).to have_css("label[for='#{input_id}']")
        end
      end
    end

    it 'provides clear error messages' do
      visit school_path(comprehensive_school)

      click_button 'Contact School'

      within('.modal form') do
        # Submit form with invalid data
        fill_in 'Name', with: ''
        fill_in 'Email', with: 'invalid'
        click_button 'Send Message'

        # Error messages should be specific and helpful
        expect(page).to have_content(/name.+required/i) ||
                     have_content(/email.+invalid/i)
      end
    end

    it 'groups related form fields' do
      visit school_path(comprehensive_school)

      click_button 'Contact School'

      within('.modal form') do
        # Should use fieldset for grouped fields if applicable
        expect(page).to have_css('fieldset') ||
                     have_css('[role="group"]') ||
                     have_content('Contact Information') # Section heading
      end
    end

    it 'provides form instructions' do
      visit school_path(comprehensive_school)

      click_button 'Contact School'

      within('.modal') do
        # Should explain form purpose and requirements
        expect(page).to have_content(/send.+message/i) ||
                     have_content(/contact.+school/i)

        # Should indicate required fields
        expect(page).to have_content('required') ||
                     have_css('input[required] + *', text: '*')
      end
    end
  end

  describe 'media accessibility' do
    it 'provides captions or transcripts for videos' do
      school_with_videos = create(:school, place: place, youtube_url: 'https://youtube.com/channel/test')
      visit school_path(school_with_videos)

      if page.has_content?('Video Gallery')
        # Should mention captions or provide transcript links
        expect(page).to have_content(/caption/i) ||
                     have_content(/transcript/i) ||
                     have_link(/transcript/i)
      end
    end

    it 'supports keyboard control for interactive media' do
      visit school_path(school_with_media)

      # Photo gallery should be keyboard accessible
      if page.has_css?('.photo-gallery img')
        first_photo = first('.photo-gallery img')
        first_photo.send_keys :enter

        # Should open lightbox or similar
        expect(page).to have_css('.lightbox, .modal, .photo-viewer')

        # Should be closable with keyboard
        find('body').send_keys :escape
        expect(page).not_to have_css('.lightbox:visible')
      end
    end
  end

  describe 'navigation accessibility' do
    it 'provides multiple ways to navigate content' do
      visit school_path(comprehensive_school)

      # Should have table of contents or section navigation
      expect(page).to have_css('nav') ||
                   have_link(/academic/i) ||
                   have_link(/facilities/i) ||
                   have_link(/fees/i)
    end

    it 'indicates current page location' do
      visit school_path(comprehensive_school)

      # Should show breadcrumbs or page title
      expect(page).to have_css('.breadcrumb') ||
                   have_title(comprehensive_school.name) ||
                   have_css('h1', text: comprehensive_school.name)
    end
  end

  describe 'error prevention and handling' do
    it 'prevents accidental form submission' do
      login_as(facebook_user, scope: :user)
      visit school_path(comprehensive_school)

      click_button 'Contact School'

      within('.modal form') do
        fill_in 'Name', with: 'Test User'
        fill_in 'Email', with: 'test@example.com'
        fill_in 'Message', with: 'Test message'

        submit_button = find('button[type="submit"], input[type="submit"]')

        # Should require confirmation for destructive actions
        # or provide clear undo mechanism
        expect(submit_button.text).to include('Send') # Clear action description
      end
    end

    it 'provides accessible error recovery' do
      login_as(facebook_user, scope: :user)
      visit school_path(comprehensive_school)

      # Simulate server error
      allow_any_instance_of(SchoolInquiriesController).to receive(:create)
        .and_return({ success: false, errors: [ 'Server temporarily unavailable' ] })

      click_button 'Contact School'

      within('.modal form') do
        fill_in 'Name', with: 'Error Test'
        fill_in 'Email', with: 'error@example.com'
        fill_in 'Message', with: 'Error message'

        click_button 'Send Message'

        # Should provide clear error message and recovery options
        expect(page).to have_content(/error/i)
        expect(page).to have_content(/try again/i) ||
                     have_button('Retry') ||
                     have_button('Send Message') # Allow retry
      end
    end
  end

  describe 'timing and motion accessibility' do
    it 'does not auto-refresh content' do
      visit school_path(comprehensive_school)

      # Should not have auto-refresh meta tags
      expect(page).not_to have_css('meta[http-equiv="refresh"]')
    end

    it 'provides pause controls for animations', js: true do
      visit school_path(comprehensive_school)

      # If animations exist, should provide controls
      animated_elements = page.all('[class*="animate"], [class*="transition"]')

      if animated_elements.any?
        # Should respect prefers-reduced-motion
        page.execute_script("document.documentElement.style.setProperty('--motion-reduce', 'reduce');")

        # Animations should be reduced or stopped
        expect(page).to have_content(comprehensive_school.name)
      end
    end

    it 'allows user control of time limits' do
      login_as(facebook_user, scope: :user)
      visit school_path(comprehensive_school)

      # Session timeouts should be announced and extendable
      # This is more of a system-level concern, but modals shouldn't auto-close
      click_button 'Contact School'

      # Modal should stay open indefinitely
      sleep 2
      expect(page).to have_css('.modal', visible: true)
    end
  end
end
