require 'rails_helper'

RSpec.describe 'School Claim Flow', type: :system do
  let(:school) { create(:school) }
  
  before do
    visit school_path(id: school.id)
  end
  
  it 'allows user to claim a school successfully', js: true do
    click_button 'Claim This School'
    
    # Fill out the claim form
    fill_in 'Email Address', with: 'owner@example.com'
    fill_in 'Evidence URL (Optional)', with: 'https://linkedin.com/in/schoolowner'
    fill_in 'Additional Information (Optional)', with: 'I am the principal of this school'
    check 'I confirm that I have the authority to represent this school'
    
    # Mock successful API response
    page.execute_script(<<~JS)
      window.fetch = function() {
        return Promise.resolve({
          ok: true,
          headers: new Headers({ 'content-type': 'application/json' }),
          json: function() {
            return Promise.resolve({
              success: true,
              title: 'Claim Submitted Successfully!',
              message: 'Your claim has been submitted for review.',
              school_name: '#{school.name}',
              school_url: '#{school_path(id: school.id)}',
              created_user: true,
              claim_id: 1
            });
          }
        });
      };
    JS
    
    # Submit the form
    click_button 'Submit Claim'
    
    # Verify modal appears with success message
    expect(page).to have_selector('[data-testid="success-modal"]', visible: true, wait: 5)
    expect(page).to have_content('Claim Submitted Successfully!')
    expect(page).to have_content(school.name)
    expect(page).to have_content('Check Your Email')
    
    # Click continue to school button
    within('.modal-content') do
      click_button 'Continue to School'
    end
    
    # Verify redirect back to school page
    expect(current_path).to eq(school_path(id: school.id))
  end
  
  it 'shows error modal for network failures', js: true do
    click_button 'Claim This School'
    
    fill_in 'Email Address', with: 'owner@example.com'
    check 'I confirm that I have the authority to represent this school'
    
    # Mock network error
    page.execute_script(<<~JS)
      window.fetch = function() {
        return Promise.reject(new Error('Network Error'));
      };
    JS
    
    click_button 'Submit Claim'
    
    # Verify error modal appears
    expect(page).to have_selector('.modal-content', visible: true, wait: 5)
    expect(page).to have_content('Submission Failed')
    expect(page).to have_content('Network error: Network Error')
  end
  
  it 'shows error modal for validation failures', js: true do
    click_button 'Claim This School'
    
    # Mock validation error response
    page.execute_script(<<~JS)
      window.fetch = function() {
        return Promise.resolve({
          ok: false,
          status: 422,
          headers: new Headers({ 'content-type': 'application/json' }),
          json: function() {
            return Promise.resolve({
              success: false,
              errors: ['Email is required', 'Terms must be agreed to']
            });
          }
        });
      };
    JS
    
    click_button 'Submit Claim'
    
    # Verify error modal with validation errors
    expect(page).to have_selector('.modal-content', visible: true, wait: 5)
    expect(page).to have_content('Submission Failed')
    expect(page).to have_content('Email is required')
    expect(page).to have_content('Terms must be agreed to')
  end
  
  it 'preserves form data when modal is dismissed', js: true do
    click_button 'Claim This School'
    
    # Fill out some form fields
    fill_in 'Email Address', with: 'test@example.com'
    fill_in 'Evidence URL (Optional)', with: 'https://example.com'
    fill_in 'Additional Information (Optional)', with: 'Test notes'
    
    # Trigger error modal
    page.execute_script(<<~JS)
      window.fetch = function() {
        return Promise.reject(new Error('Test Error'));
      };
    JS
    
    click_button 'Submit Claim'
    
    # Close error modal
    expect(page).to have_content('Network error: Test Error', wait: 5)
    click_button 'Cancel'
    
    # Verify form data is preserved
    expect(find_field('Email Address').value).to eq('test@example.com')
    expect(find_field('Evidence URL (Optional)').value).to eq('https://example.com')
    expect(find_field('Additional Information (Optional)').value).to eq('Test notes')
  end
  
  context 'when user is already signed in' do
    let(:user) { create(:user, email: 'signed_in@example.com') }
    
    before do
      # Simulate user authentication in browser
      page.execute_script(<<~JS)
        document.cookie = 'user_signed_in=true; path=/';
      JS
      visit school_path(id: school.id)
    end
    
    it 'pre-fills email field for signed in users', js: true do
      click_button 'Claim This School'
      
      # The email field should be pre-filled and disabled
      email_field = find_field('Email Address')
      expect(email_field.value).to eq('signed_in@example.com')
      expect(email_field[:readonly]).to be_truthy
    end
  end
end