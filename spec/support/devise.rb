# frozen_string_literal: true

RSpec.configure do |config|
  # Include Devise test helpers for different test types
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :system
  
  # For feature tests (if using Capybara)
  config.include Warden::Test::Helpers, type: :system
  config.include Warden::Test::Helpers, type: :feature
  
  # Clean up after each test (only for system/feature tests that use Warden)
  config.after :each, type: :system do
    Warden.test_reset!
  end
  
  config.after :each, type: :feature do
    Warden.test_reset!
  end
end