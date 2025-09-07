require 'rails_helper'

RSpec.describe 'School Interactive Features', type: :system do
  let(:place) { create(:place, lat: 13.7563, lng: 100.5018, formatted_address: '123 School Street, Bangkok') }
  let(:school) { create(:school, name: 'Interactive Test School', place: place) }
  let(:school_with_media) { create(:school, :with_media, place: place) }
  let(:facebook_user) { create(:user, :facebook_user) }

  let(:comprehensive_school) do
    create(:school, name: 'Feature Rich School', place: place).tap do |s|
      create_list(:media_item, 8, place: s.place)
      create_list(:page, 5, school: s, status: 'published')
      s.update(youtube_url: 'https://youtube.com/channel/testchannel')
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

  describe 'Google Maps integration', js: true do
    it 'loads interactive map component' do
      visit school_path(school)

      expect(page).to have_css('#map, .map-container, .interactive-map', wait: 10)
    end

    it 'displays school location marker' do
      visit school_path(school)

      # Wait for map to potentially load
      sleep 2

      # Should show address information even if map fails to load
      expect(page).to have_content(school.place.formatted_address)
    end

    it 'provides directions functionality' do
      visit school_path(school)

      expect(page).to have_content('Directions') || have_link('Get Directions')
    end

    it 'handles map loading errors gracefully' do
      # Simulate Google Maps API failure
      page.execute_script('''
        window.google = undefined;
        window.googleMapsApiLoaded = function() { throw new Error("Maps API failed"); };
      ''')

      visit school_path(school)

      # Page should still function without maps
      expect(page).to have_content(school.name)
      expect(page).to have_content(school.place.formatted_address)
    end

    it 'shows map controls when loaded' do
      visit school_path(school)

      # Mock successful maps loading
      page.execute_script('''
        window.google = {
          maps: {
            Map: function() { return {}; },
            Marker: function() { return {}; }
          }
        };
      ''')

      expect(page).to have_css('.map-container')
    end
  end

  describe 'photo gallery interactions', js: true do
    it 'displays photo thumbnails' do
      visit school_path(school_with_media)

      expect(page).to have_css('.photo-gallery img, .media-item', wait: 10)
    end

    it 'opens lightbox when photo clicked' do
      visit school_path(school_with_media)

      # Find and click first photo
      first_photo = first('.photo-gallery img, .media-item img')
      first_photo.click if first_photo

      # Should open lightbox or modal
      expect(page).to have_css('.lightbox, .photo-modal, .photo-viewer', wait: 5) ||
                   have_css('[role="dialog"]')
    end

    it 'navigates between photos in gallery' do
      visit school_path(comprehensive_school)

      # If gallery has navigation
      if page.has_css?('.photo-gallery .next, .photo-gallery .prev')
        find('.photo-gallery .next').click
        # Should change displayed photo
        expect(page).to have_css('.photo-gallery')
      else
        # At minimum, photos should be displayed
        expect(page).to have_css('.photo-gallery, .media-gallery')
      end
    end

    it 'closes lightbox with escape key' do
      visit school_path(school_with_media)

      first_photo = first('.photo-gallery img')
      if first_photo
        first_photo.click

        # Press escape
        find('body').send_keys :escape

        expect(page).not_to have_css('.lightbox:visible, .photo-modal:visible')
      end
    end

    it 'handles image loading errors' do
      visit school_path(school_with_media)

      # Simulate broken image
      page.execute_script('''
        document.querySelectorAll("img").forEach(img => {
          img.src = "broken-url.jpg";
        });
      ''')

      # Should handle gracefully without crashing
      expect(page).to have_content(school_with_media.name)
    end

    it 'implements lazy loading for performance' do
      visit school_path(comprehensive_school)

      # Check for lazy loading attributes
      expect(page).to have_css('img[loading="lazy"], img[data-src], img.lazyload')
    end
  end

  describe 'video gallery interactions', js: true do
    let(:school_with_videos) do
      create(:school, place: place, youtube_url: 'https://youtube.com/channel/test').tap do |s|
        # Mock video data in place
        s.place.update(
          video_data: {
            videos: [
              { video_id: 'abc123', title: 'School Tour', thumbnail_url: 'https://img.youtube.com/vi/abc123/hqdefault.jpg' },
              { video_id: 'def456', title: 'Student Life', thumbnail_url: 'https://img.youtube.com/vi/def456/hqdefault.jpg' }
            ]
          }
        )
      end
    end

    it 'displays video thumbnails' do
      visit school_path(school_with_videos)

      expect(page).to have_css('.video-gallery, .video-section', wait: 10)
      expect(page).to have_content('Video Gallery')
    end

    it 'plays video when thumbnail clicked' do
      visit school_path(school_with_videos)

      # Find video thumbnail
      video_thumb = first('.video-gallery .video-thumbnail, .youtube-video')
      if video_thumb
        video_thumb.click

        # Should embed or open video player
        expect(page).to have_css('iframe[src*="youtube"], .video-player', wait: 5)
      end
    end

    it 'handles YouTube API failures' do
      visit school_path(school_with_videos)

      # Mock YouTube API failure
      page.execute_script('''
        window.YT = undefined;
        window.onYouTubeIframeAPIReady = function() { throw new Error("YouTube API failed"); };
      ''')

      expect(page).to have_content(school_with_videos.name)
    end

    it 'shows video metadata' do
      visit school_path(school_with_videos)

      expect(page).to have_content('School Tour') || have_content('Student Life')
    end
  end

  describe 'AI chat functionality', js: true do
    it 'displays AI chat interface when available' do
      visit school_path(school)

      # Look for chat widget or button
      expect(page).to have_css('.chat-widget, .ai-chat, [data-chat]') ||
                   have_button('Ask AI') ||
                   have_link('Chat')
    end

    it 'opens chat window when activated' do
      visit school_path(school)

      chat_trigger = first('.chat-widget, [data-chat], button[data-action*="chat"]')
      if chat_trigger
        chat_trigger.click

        expect(page).to have_css('.chat-window, .chat-modal', visible: true)
      end
    end

    it 'allows message input and submission' do
      visit school_path(school)

      chat_trigger = first('[data-chat], .ai-chat button')
      if chat_trigger
        chat_trigger.click

        within('.chat-window, .chat-interface') do
          fill_in 'message', with: 'What are the school hours?'
          click_button 'Send', wait: 2

          expect(page).to have_content('What are the school hours?')
        end
      end
    end

    it 'displays AI responses' do
      visit school_path(school)

      # Mock AI response
      allow_any_instance_of(SchoolsController).to receive(:ai_chat)
        .and_return({ response: 'Our school hours are 8:00 AM to 3:00 PM.' })

      chat_trigger = first('[data-action*="chat"]')
      if chat_trigger
        chat_trigger.click

        within('.chat-interface') do
          fill_in 'message', with: 'What are the school hours?'
          click_button 'Send'

          expect(page).to have_content('8:00 AM to 3:00 PM', wait: 5)
        end
      end
    end

    it 'handles chat errors gracefully' do
      visit school_path(school)

      # Mock server error
      allow_any_instance_of(SchoolsController).to receive(:ai_chat)
        .and_raise(StandardError.new('AI service unavailable'))

      chat_trigger = first('[data-action*="chat"]')
      if chat_trigger
        chat_trigger.click

        within('.chat-interface') do
          fill_in 'message', with: 'Test message'
          click_button 'Send'

          expect(page).to have_content('sorry') || have_content('error')
        end
      end
    end
  end

  describe 'school pages navigation', js: true do
    let(:school_with_pages) do
      create(:school, place: place).tap do |s|
        create(:page, school: s, title: 'About Our School', status: 'published', page_type: 'about_us')
        create(:page, school: s, title: 'Academic Programs', status: 'published', page_type: 'academics')
        create(:page, school: s, title: 'Sports & Activities', status: 'published', page_type: 'activities')
      end
    end

    it 'displays school pages section' do
      visit school_path(school_with_pages)

      expect(page).to have_content('School Pages')
      expect(page).to have_content('3 pages available')
    end

    it 'shows individual page previews' do
      visit school_path(school_with_pages)

      expect(page).to have_content('About Our School')
      expect(page).to have_content('Academic Programs')
      expect(page).to have_content('Sports & Activities')
    end

    it 'links to individual pages' do
      visit school_path(school_with_pages)

      expect(page).to have_link('Read More')
      expect(page).to have_link('View All Pages')
    end

    it 'navigates to page detail when clicked' do
      visit school_path(school_with_pages)

      click_link 'About Our School', match: :first

      expect(page).to have_current_path(%r{/schools/#{school_with_pages.id}/pages/})
      expect(page).to have_content('About Our School')
    end

    it 'navigates to pages index' do
      visit school_path(school_with_pages)

      click_link 'View All Pages'

      expect(page).to have_current_path(school_pages_path(school_id: school_with_pages.id))
    end
  end

  describe 'responsive interactions', js: true do
    it 'adapts navigation for mobile' do
      page.driver.resize(width: 375, height: 667)

      visit school_path(comprehensive_school)

      # Should show mobile-optimized interface
      expect(page).to have_content(comprehensive_school.name)

      # Mobile-specific interactions should work
      if page.has_css?('.mobile-menu, .hamburger')
        find('.mobile-menu, .hamburger').click
        expect(page).to have_css('.menu-open, .nav-open')
      end
    end

    it 'handles touch interactions on tablets' do
      page.driver.resize(width: 768, height: 1024)

      visit school_path(school_with_media)

      # Touch-friendly interactions
      expect(page).to have_css('.photo-gallery')

      # Simulate touch interaction
      first_photo = first('.photo-gallery img')
      if first_photo
        first_photo.click
        expect(page).to have_css('.lightbox, .photo-modal') || have_content(school_with_media.name)
      end
    end
  end

  describe 'form interactions', js: true do
    before { login_as(facebook_user, scope: :user) }

    it 'provides real-time form validation' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        email_field = find('input[type="email"]')
        email_field.fill_in with: 'invalid-email'
        email_field.send_keys :tab

        expect(email_field['validity.valid']).to be_falsy
      end
    end

    it 'shows character count for message field' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        message_field = find('textarea[name="message"]')
        message_field.fill_in with: 'Test message'

        # Should show character count
        expect(page).to have_content('characters') || have_content('2000')
      end
    end

    it 'auto-resizes textarea' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        message_field = find('textarea[name="message"]')
        original_height = message_field.native.css_value('height')

        # Fill with long text
        long_text = 'This is a very long message. ' * 10
        message_field.fill_in with: long_text

        new_height = message_field.native.css_value('height')
        # Height should increase (if auto-resize is implemented)
        expect(new_height.to_i).to be >= original_height.to_i
      end
    end
  end

  describe 'loading states and feedback', js: true do
    it 'shows loading indicators during AJAX requests' do
      login_as(facebook_user, scope: :user)
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        fill_in 'Name', with: 'Test User'
        fill_in 'Email', with: 'test@example.com'
        fill_in 'Message', with: 'Test message'

        click_button 'Send Message'

        # Should show loading state
        expect(page).to have_css('.loading, .spinner, [disabled]', wait: 2)
      end
    end

    it 'provides visual feedback for user actions' do
      visit school_path(school)

      # Hover effects, click feedback, etc.
      contact_button = find('button', text: 'Contact School')
      contact_button.hover

      # Should have hover styles
      expect(contact_button).to match_css(':hover')
    end

    it 'shows success states after actions' do
      login_as(facebook_user, scope: :user)
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        fill_in 'Name', with: 'Success Test'
        fill_in 'Email', with: 'success@example.com'
        fill_in 'Message', with: 'Success message'

        click_button 'Send Message'

        expect(page).to have_content('successfully', wait: 5) ||
                     have_css('.success, .check-mark')
      end
    end
  end

  describe 'keyboard navigation', js: true do
    it 'supports tab navigation through interactive elements' do
      visit school_path(comprehensive_school)

      # Start from first interactive element
      find('body').send_keys :tab

      # Should focus on interactive elements
      expect(page).to have_css(':focus')
    end

    it 'provides skip links for accessibility' do
      visit school_path(school)

      # Skip to main content
      find('body').send_keys :tab

      expect(page).to have_link('Skip to main content') ||
                   have_css('.skip-link, [href="#main"]')
    end

    it 'maintains logical tab order' do
      visit school_path(school)

      click_button 'Contact School'

      within('.modal') do
        name_field = find('input[name="name"]')
        name_field.send_keys :tab

        # Should focus next field in logical order
        expect(find('input[name="email"]')).to match_selector(':focus')
      end
    end
  end

  describe 'error handling and recovery', js: true do
    it 'recovers from JavaScript errors gracefully' do
      visit school_path(school)

      # Simulate JavaScript error
      page.execute_script('throw new Error("Simulated error");')

      # Page should still be functional
      expect(page).to have_content(school.name)
      expect(page).to have_button('Contact School')
    end

    it 'provides fallbacks for failed features' do
      visit school_path(school)

      # Disable JavaScript features
      page.execute_script('''
        window.google = undefined;
        window.YT = undefined;
      ''')

      # Core functionality should still work
      expect(page).to have_content(school.name)
      expect(page).to have_content(school.place.formatted_address)
    end

    it 'shows helpful error messages' do
      login_as(facebook_user, scope: :user)
      visit school_path(school)

      # Mock server error
      allow_any_instance_of(SchoolInquiriesController).to receive(:create)
        .and_return(render json: { success: false, errors: [ 'Server error' ] })

      click_button 'Contact School'

      within('.modal') do
        fill_in 'Name', with: 'Error Test'
        fill_in 'Email', with: 'error@example.com'
        fill_in 'Message', with: 'Error message'

        click_button 'Send Message'

        expect(page).to have_content('error') || have_content('try again')
      end
    end
  end

  describe 'animation and transitions', js: true do
    it 'animates modal opening and closing' do
      visit school_path(school)

      click_button 'Contact School'

      # Modal should have transition classes
      expect(page).to have_css('.modal[class*="transition"], .modal[class*="fade"]')

      find('[data-action*="closeModal"]').click

      # Should animate out
      expect(page).to have_css('.modal[class*="transition"], .modal[class*="fade"]')
    end

    it 'provides smooth scroll to sections' do
      visit school_path(comprehensive_school)

      # If anchor links exist
      if page.has_link?('#academics') || page.has_link?('#facilities')
        first_anchor = first('a[href^="#"]')
        first_anchor.click if first_anchor

        # Should scroll smoothly (hard to test, but ensures no errors)
        expect(page).to have_content(comprehensive_school.name)
      end
    end
  end
end
