# Rails Testing Implementation Guide

This guide provides comprehensive testing practices for a Ruby on Rails application with Stimulus controllers and Hotwire.

## Table of Contents

1. [Setup and Installation](#setup-and-installation)
2. [Testing Framework Configuration](#testing-framework-configuration)
3. [Test Types and Structure](#test-types-and-structure)
4. [Factory Definitions](#factory-definitions)
5. [Unit Testing (Models, Services)](#unit-testing-models-services)
6. [Integration Testing (Request Specs)](#integration-testing-request-specs)
7. [System Testing (End-to-End with Stimulus)](#system-testing-end-to-end-with-stimulus)
8. [Stimulus Controller Testing](#stimulus-controller-testing)
9. [Test Execution Commands](#test-execution-commands)
10. [Best Practices](#best-practices)

## Setup and Installation

### Required Gems

Add to your `Gemfile`:

```ruby
group :development, :test do
  gem "faker", "~> 3.2"
  gem 'pry-byebug'
end

group :test do
  gem 'rspec-rails', '~> 6.0'
  gem 'factory_bot_rails', '~> 6.2'
  gem 'shoulda-matchers', '~> 5.3'
  gem 'capybara', '~> 3.39'
  gem 'cuprite', '~> 0.15'  # Headless Chrome driver
  gem 'webmock', '~> 3.18'
  gem 'database_cleaner-active_record', '~> 2.1'
end
```

### Installation Commands

```bash
# Install gems
bundle install

# Generate RSpec configuration
rails generate rspec:install

# Create spec directories
mkdir -p spec/{models,requests,system,factories,support}
```

## Testing Framework Configuration

### spec/rails_helper.rb

```ruby
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
abort("Rails is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'capybara/rails'
require 'capybara/cuprite'

# Configure Capybara for system tests
Capybara.register_driver :cuprite do |app|
  Capybara::Cuprite::Driver.new(app, {
    window_size: [1200, 800],
    inspector: true,
    headless: !ENV['HEADLESS'].in?(['n', 'no', 'false'])
  })
end

Capybara.default_driver = :cuprite
Capybara.javascript_driver = :cuprite
Capybara.default_max_wait_time = 5

# Load support files
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  
  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods
  
  # Include Capybara DSL in system tests
  config.include Capybara::DSL, type: :system
end
```

### spec/support/database_cleaner.rb

```ruby
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.around(:each, type: :system) do |example|
    DatabaseCleaner.strategy = :truncation
    example.run
    DatabaseCleaner.strategy = :transaction
  end
end
```

### spec/support/shoulda_matchers.rb

```ruby
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
```

### spec/support/webmock.rb

```ruby
require 'webmock/rspec'

RSpec.configure do |config|
  config.before(:each) do
    WebMock.disable_net_connect!(allow_localhost: true)
  end
end
```

## Test Types and Structure

### Directory Structure

```
spec/
├── factories/           # FactoryBot definitions
├── models/             # Unit tests for models
├── requests/           # Integration tests for controllers
├── services/           # Unit tests for service objects
├── system/             # End-to-end browser tests
├── support/            # Test configuration and helpers
├── fixtures/           # Static test data files
└── rails_helper.rb     # RSpec configuration
```

## Factory Definitions

### Basic Factory Structure

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.unique.email }
    password { 'password123' }
    confirmed_at { Time.current }
    
    trait :admin do
      role { 'admin' }
    end
    
    trait :unconfirmed do
      confirmed_at { nil }
    end
    
    trait :with_avatar do
      after(:build) do |user|
        user.avatar.attach(
          io: File.open(Rails.root.join('spec', 'fixtures', 'avatar.png')),
          filename: 'avatar.png',
          content_type: 'image/png'
        )
      end
    end
  end
end

# spec/factories/schools.rb
FactoryBot.define do
  factory :school do
    name { Faker::Educator.secondary_school }
    slug { name.parameterize }
    about { Faker::Lorem.paragraph(sentence_count: 3) }
    phone { Faker::PhoneNumber.phone_number }
    email { Faker::Internet.email }
    website_url { Faker::Internet.url }
    lat { Faker::Address.latitude }
    lng { Faker::Address.longitude }
    status { 'published' }
    
    association :place
    
    trait :draft do
      status { 'draft' }
    end
    
    trait :with_media do
      after(:create) do |school|
        create_list(:media_item, 3, place: school.place)
      end
    end
  end
end
```

## Unit Testing (Models, Services)

### Model Testing Example

```ruby
# spec/models/user_spec.rb
RSpec.describe User, type: :model do
  describe 'validations' do
    subject { build(:user) }
    
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_presence_of(:password) }
    it { should validate_length_of(:password).is_at_least(6) }
  end

  describe 'associations' do
    it { should have_many(:school_claims).dependent(:destroy) }
    it { should have_many(:inquiries).dependent(:destroy) }
  end
  
  describe 'enums' do
    it { should define_enum_for(:role).with_values(school_owner: 0, admin: 1) }
  end

  describe '#full_name' do
    let(:user) { create(:user, first_name: 'John', last_name: 'Doe') }
    
    it 'returns concatenated first and last name' do
      expect(user.full_name).to eq('John Doe')
    end
    
    context 'when last name is missing' do
      let(:user) { create(:user, first_name: 'John', last_name: nil) }
      
      it 'returns only first name' do
        expect(user.full_name).to eq('John')
      end
    end
  end
  
  describe '#admin?' do
    it 'returns true for admin users' do
      admin = create(:user, :admin)
      expect(admin.admin?).to be true
    end
    
    it 'returns false for school owner users' do
      user = create(:user)
      expect(user.admin?).to be false
    end
  end
end
```

### Service Object Testing Example

```ruby
# spec/services/auto_claim_service_spec.rb
RSpec.describe AutoClaimService, type: :service do
  let(:school) { create(:school) }
  let(:email) { 'test@example.com' }
  let(:service) { described_class.new(email: email, school: school) }

  describe '#call' do
    context 'when user does not exist' do
      it 'creates a new user and school claim' do
        expect { service.call }.to change(User, :count).by(1)
                               .and change(SchoolClaim, :count).by(1)
        
        result = service.call
        expect(result[:success]).to be true
        expect(result[:created_user]).to be true
        expect(result[:school_claim]).to be_present
      end
    end
    
    context 'when user already exists' do
      let!(:existing_user) { create(:user, email: email) }
      
      it 'creates only a school claim' do
        expect { service.call }.to change(SchoolClaim, :count).by(1)
                               .and not_change(User, :count)
        
        result = service.call
        expect(result[:success]).to be true
        expect(result[:created_user]).to be false
      end
    end
    
    context 'when user already has a claim for the school' do
      let!(:user) { create(:user, email: email) }
      let!(:existing_claim) { create(:school_claim, user: user, school: school) }
      
      it 'returns failure' do
        result = service.call
        expect(result[:success]).to be false
        expect(result[:message]).to include('already claimed')
      end
    end
  end
end
```

## Integration Testing (Request Specs)

### Controller Testing Example

```ruby
# spec/requests/schools_spec.rb
RSpec.describe 'Schools', type: :request do
  describe 'GET /schools' do
    let!(:schools) { create_list(:school, 3) }
    
    it 'returns successful response' do
      get schools_path
      expect(response).to have_http_status(:ok)
    end
    
    it 'includes all published schools' do
      get schools_path
      schools.each do |school|
        expect(response.body).to include(school.name)
      end
    end
    
    context 'with search parameter' do
      let!(:matching_school) { create(:school, name: 'Special School') }
      
      it 'returns filtered results' do
        get schools_path, params: { q: 'Special' }
        expect(response.body).to include('Special School')
      end
    end
  end
  
  describe 'GET /schools/:id' do
    let(:school) { create(:school) }
    
    it 'returns successful response' do
      get school_path(id: school.id)
      expect(response).to have_http_status(:ok)
    end
    
    it 'displays school information' do
      get school_path(id: school.id)
      expect(response.body).to include(school.name)
      expect(response.body).to include(school.about)
    end
    
    context 'when school does not exist' do
      it 'returns not found' do
        get school_path(id: 'non-existent')
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end

# spec/requests/direct_claims_spec.rb
RSpec.describe 'DirectClaims', type: :request do
  let(:school) { create(:school) }
  
  describe 'POST /schools/:school_id/claim' do
    let(:valid_params) do
      {
        direct_claim: {
          email: 'test@example.com',
          evidence_url: 'https://example.com/evidence',
          notes: 'I am the school owner'
        }
      }
    end
    
    context 'with valid parameters' do
      it 'creates a school claim' do
        expect {
          post create_direct_claim_path(school_id: school.id), params: valid_params
        }.to change(SchoolClaim, :count).by(1)
      end
      
      it 'returns JSON success response' do
        post create_direct_claim_path(school_id: school.id), 
             params: valid_params,
             headers: { 'Accept' => 'application/json' }
        
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['success']).to be true
      end
    end
    
    context 'with invalid parameters' do
      let(:invalid_params) do
        { direct_claim: { email: '' } }
      end
      
      it 'returns validation errors' do
        post create_direct_claim_path(school_id: school.id), 
             params: invalid_params,
             headers: { 'Accept' => 'application/json' }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['success']).to be false
      end
    end
  end
end
```

## System Testing (End-to-End with Stimulus)

### System Test Examples

```ruby
# spec/system/school_claim_flow_spec.rb
RSpec.describe 'School Claim Flow', type: :system do
  let(:school) { create(:school) }
  
  before do
    visit school_path(id: school.id)
  end
  
  it 'allows user to claim a school', js: true do
    click_button 'Claim This School'
    
    # Fill out the claim form
    fill_in 'Email', with: 'owner@example.com'
    fill_in 'Evidence URL', with: 'https://linkedin.com/in/schoolowner'
    fill_in 'Additional Information', with: 'I am the principal of this school'
    check 'I confirm that I have the authority to represent this school'
    
    # Submit the form
    click_button 'Submit Claim'
    
    # Verify modal appears with success message
    expect(page).to have_selector('[data-testid="success-modal"]', visible: true)
    expect(page).to have_content('Claim Submitted Successfully!')
    expect(page).to have_content(school.name)
    
    # Click continue to school button
    within('[data-testid="success-modal"]') do
      click_button 'Continue to School'
    end
    
    # Verify redirect back to school page
    expect(current_path).to eq(school_path(id: school.id))
  end
  
  it 'shows error modal for invalid submission', js: true do
    click_button 'Claim This School'
    
    # Submit form without required fields
    click_button 'Submit Claim'
    
    # Verify error modal appears
    expect(page).to have_selector('[data-testid="error-modal"]', visible: true)
    expect(page).to have_content('Submission Failed')
  end
  
  it 'preserves form data when form fails', js: true do
    click_button 'Claim This School'
    
    fill_in 'Evidence URL', with: 'https://example.com'
    fill_in 'Additional Information', with: 'Test notes'
    
    # Submit without email (should fail)
    click_button 'Submit Claim'
    
    # Close error modal
    click_button 'Try Again'
    
    # Verify form data is preserved
    expect(find_field('Evidence URL').value).to eq('https://example.com')
    expect(find_field('Additional Information').value).to eq('Test notes')
  end
end

# spec/system/school_search_spec.rb
RSpec.describe 'School Search', type: :system do
  let!(:bangkok_school) { create(:school, name: 'Bangkok International School') }
  let!(:phuket_school) { create(:school, name: 'Phuket Academy') }
  
  before do
    visit root_path
  end
  
  it 'searches for schools dynamically', js: true do
    # Type in search box
    fill_in 'search_query', with: 'Bangkok'
    
    # Wait for AJAX search results
    expect(page).to have_content('Bangkok International School')
    expect(page).not_to have_content('Phuket Academy')
    
    # Clear search
    fill_in 'search_query', with: ''
    
    # Should show all schools
    expect(page).to have_content('Bangkok International School')
    expect(page).to have_content('Phuket Academy')
  end
  
  it 'handles empty search results', js: true do
    fill_in 'search_query', with: 'Nonexistent School'
    
    expect(page).to have_content('No schools found')
  end
end
```

## Stimulus Controller Testing

### Testing Stimulus Controllers through System Tests

```ruby
# spec/system/interactive_components_spec.rb
RSpec.describe 'Interactive Components', type: :system do
  
  describe 'Toggle Controller' do
    before do
      # Setup page with toggle component
      page.driver.browser.navigate.to("data:text/html,#{toggle_component_html}")
    end
    
    it 'toggles content visibility', js: true do
      # Initial state - content hidden
      expect(page).to have_selector('[data-testid="toggle-content"]', visible: false)
      
      # Click toggle button
      click_button 'Toggle Content'
      
      # Content should now be visible
      expect(page).to have_selector('[data-testid="toggle-content"]', visible: true)
      
      # Click again to hide
      click_button 'Toggle Content'
      expect(page).to have_selector('[data-testid="toggle-content"]', visible: false)
    end
    
    it 'updates button text based on state', js: true do
      expect(page).to have_button('Show Content')
      
      click_button 'Show Content'
      expect(page).to have_button('Hide Content')
      
      click_button 'Hide Content'
      expect(page).to have_button('Show Content')
    end
    
    private
    
    def toggle_component_html
      <<~HTML
        <div data-controller="toggle" data-testid="toggle-container">
          <button data-action="click->toggle#toggle" 
                  data-testid="toggle-button"
                  data-toggle-target="button">
            Show Content
          </button>
          <div data-toggle-target="content" 
               data-testid="toggle-content" 
               class="hidden">
            <p>This content can be toggled</p>
          </div>
        </div>
        <script>
          // Minimal Stimulus setup for testing
          import { Controller } from "@hotwired/stimulus";
          class ToggleController extends Controller {
            static targets = ["content", "button"]
            
            toggle() {
              this.contentTarget.classList.toggle("hidden");
              this.buttonTarget.textContent = this.contentTarget.classList.contains("hidden") 
                ? "Show Content" 
                : "Hide Content";
            }
          }
        </script>
      HTML
    end
  end
  
  describe 'Form Submission Controller' do
    let(:school) { create(:school) }
    
    before do
      visit new_direct_claim_path(school_id: school.id)
    end
    
    it 'handles form submission with AJAX', js: true do
      # Fill out form
      fill_in 'Email', with: 'test@example.com'
      fill_in 'Evidence URL', with: 'https://example.com'
      
      # Mock successful API response
      page.execute_script(<<~JS)
        window.fetch = function() {
          return Promise.resolve({
            ok: true,
            json: function() {
              return Promise.resolve({
                success: true,
                title: 'Claim Submitted Successfully!',
                message: 'Your claim has been submitted for review.',
                school_name: '#{school.name}',
                school_url: '#{school_path(id: school.id)}'
              });
            }
          });
        };
      JS
      
      # Submit form
      click_button 'Submit Claim'
      
      # Verify modal appears
      expect(page).to have_selector('[data-testid="success-modal"]', visible: true)
      expect(page).to have_content('Claim Submitted Successfully!')
    end
  end
end
```

### HTML Markup for Testable Stimulus Components

```erb
<!-- Use data-testid for reliable element selection -->
<div data-controller="school-contact-modal" 
     data-testid="contact-modal-container"
     data-school-contact-modal-school-id-value="<%= @school.id %>"
     data-school-contact-modal-user-signed-in-value="<%= user_signed_in? %>">
  
  <button data-action="click->school-contact-modal#open" 
          data-testid="open-contact-button">
    Contact School
  </button>
  
  <div data-school-contact-modal-target="modal" 
       data-testid="contact-modal"
       class="hidden">
    <form data-action="submit->school-contact-modal#submit">
      <input data-testid="contact-name" type="text" name="name">
      <input data-testid="contact-email" type="email" name="email">
      <textarea data-testid="contact-message" name="message"></textarea>
      <button data-testid="submit-contact" type="submit">Send Message</button>
    </form>
  </div>
</div>
```

## Test Execution Commands

### Basic Commands

```bash
# Install test dependencies
bundle install

# Run all tests
bundle exec rspec

# Run specific test types
bundle exec rspec spec/models          # Unit tests only
bundle exec rspec spec/requests        # Integration tests only  
bundle exec rspec spec/system          # System tests only

# Run tests with specific tags
bundle exec rspec --tag js             # JavaScript-enabled tests only
bundle exec rspec --tag ~slow          # Exclude slow tests

# Run tests with visible browser (for debugging)
HEADLESS=no bundle exec rspec spec/system

# Run specific test files
bundle exec rspec spec/models/user_spec.rb
bundle exec rspec spec/system/school_claim_flow_spec.rb

# Run specific test examples
bundle exec rspec spec/models/user_spec.rb:25  # Run test at line 25
```

### Advanced Commands

```bash
# Run tests in parallel (if using parallel_tests gem)
bundle exec parallel_rspec spec/

# Generate test coverage report (if using simplecov)
COVERAGE=true bundle exec rspec

# Run tests with profiling
bundle exec rspec --profile 10

# Run failed tests from previous run
bundle exec rspec --only-failures

# Run tests and stop on first failure
bundle exec rspec --fail-fast
```

## Best Practices

### General Testing Principles

1. **Test Behavior, Not Implementation**
   ```ruby
   # Good - tests behavior
   it 'sends welcome email when user is created' do
     expect { create(:user) }.to change { ActionMailer::Base.deliveries.count }.by(1)
   end
   
   # Avoid - tests implementation details
   it 'calls UserMailer.welcome after create' do
     expect(UserMailer).to receive(:welcome)
     create(:user)
   end
   ```

2. **Use Descriptive Test Names**
   ```ruby
   # Good - clear and descriptive
   it 'redirects to school page after successful claim submission'
   
   # Avoid - vague
   it 'works correctly'
   ```

3. **Follow AAA Pattern (Arrange, Act, Assert)**
   ```ruby
   it 'creates a school claim for valid submission' do
     # Arrange
     school = create(:school)
     user = create(:user)
     
     # Act
     post create_direct_claim_path(school_id: school.id), params: valid_params
     
     # Assert
     expect(response).to have_http_status(:created)
     expect(SchoolClaim.last.school).to eq(school)
   end
   ```

### Factory Best Practices

1. **Use Traits for Variations**
   ```ruby
   factory :user do
     email { Faker::Internet.email }
     
     trait :admin do
       role { 'admin' }
     end
     
     trait :with_avatar do
       # Implementation
     end
   end
   
   # Usage
   admin_user = create(:user, :admin)
   user_with_avatar = create(:user, :with_avatar)
   ```

2. **Keep Factories Minimal**
   ```ruby
   # Good - only required attributes
   factory :school do
     name { Faker::Educator.school }
     status { 'published' }
   end
   
   # Avoid - unnecessary attributes that slow tests
   factory :school do
     name { Faker::Educator.school }
     about { Faker::Lorem.paragraphs(number: 10).join("\n") }
     # ... many other attributes
   end
   ```

### System Test Best Practices

1. **Use Stable Selectors**
   ```ruby
   # Good - stable data-testid
   find('[data-testid="submit-button"]').click
   
   # Avoid - CSS classes that might change
   find('.btn-primary').click
   ```

2. **Wait for Dynamic Content**
   ```ruby
   # Good - explicit wait
   expect(page).to have_content('Success!', wait: 5)
   
   # Good - wait for specific element
   expect(page).to have_selector('[data-testid="success-modal"]', visible: true)
   ```

3. **Test User Workflows, Not Individual Components**
   ```ruby
   # Good - complete user workflow
   it 'allows user to claim school and receive confirmation' do
     visit school_path(id: school.id)
     click_button 'Claim This School'
     fill_out_claim_form
     click_button 'Submit Claim'
     expect_success_modal
     click_continue_to_school
     expect_to_be_on_school_page
   end
   ```

### Performance Considerations

1. **Use `build` Instead of `create` When Possible**
   ```ruby
   # Good - doesn't hit database
   user = build(:user)
   expect(user.full_name).to eq('John Doe')
   
   # Avoid - unnecessary database call
   user = create(:user)
   expect(user.full_name).to eq('John Doe')
   ```

2. **Use `let!` Only When Necessary**
   ```ruby
   # Good - lazy evaluation
   let(:user) { create(:user) }
   
   # Only use when needed in before blocks or across examples
   let!(:user) { create(:user) }
   ```

3. **Minimize Database Queries in System Tests**
   ```ruby
   # Good - create test data efficiently
   before do
     create_list(:school, 5)
   end
   
   # Avoid - creating data in individual examples
   ```

### Debugging Test Failures

1. **Use `save_and_open_page` for System Tests**
   ```ruby
   it 'displays school information' do
     visit school_path(id: school.id)
     save_and_open_page  # Opens browser with current page state
     expect(page).to have_content(school.name)
   end
   ```

2. **Add Screenshots on Failure**
   ```ruby
   RSpec.configure do |config|
     config.after(:each, type: :system) do |example|
       if example.exception
         save_screenshot("tmp/screenshots/#{example.description.parameterize}.png")
       end
     end
   end
   ```

3. **Use `binding.pry` for Debugging**
   ```ruby
   it 'processes complex logic' do
     result = complex_calculation
     binding.pry  # Pause execution for debugging
     expect(result).to eq(expected_value)
   end
   ```

### Continuous Integration

1. **Parallel Test Execution**
   ```yaml
   # .github/workflows/test.yml
   - name: Run tests
     run: bundle exec parallel_rspec spec/
     env:
       PARALLEL_TEST_PROCESSORS: 4
   ```

2. **Browser Dependencies for System Tests**
   ```yaml
   - name: Setup Chrome
     uses: browser-actions/setup-chrome@latest
   
   - name: Run system tests
     run: bundle exec rspec spec/system
     env:
       HEADLESS: true
   ```

3. **Test Database Configuration**
   ```yaml
   # config/database.yml
   test:
     database: myapp_test<%= ENV['TEST_ENV_NUMBER'] %>
     # Other database configuration
   ```

This comprehensive guide provides everything needed to implement robust testing for your Rails application with Stimulus controllers. Remember to start small and gradually build up your test suite, focusing on the most critical user workflows first.