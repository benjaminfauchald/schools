require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
abort("Rails is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'capybara/rails'
require 'capybara/cuprite'
require 'rails-controller-testing'
require 'database_cleaner/active_record'
Rails::Controller::Testing.install

$VERBOSE = nil if Rails.env.test?

# Configure Capybara for system tests
Capybara.register_driver :cuprite do |app|
  Capybara::Cuprite::Driver.new(app, {
    window_size: [ 1200, 800 ],
    inspector: false,  # Disable inspector for performance
    headless: !ENV['HEADLESS'].in?([ 'n', 'no', 'false' ]),
    browser_options: {
      'no-sandbox' => nil,
      'disable-web-security' => nil,
      'disable-features' => 'VizDisplayCompositor',
      'disable-blink-features' => 'AutomationControlled',
      'disable-site-isolation-trials' => nil,
      'ignore-certificate-errors' => nil,
      'disable-gpu' => nil,  # Improve performance
      'disable-dev-shm-usage' => nil  # Prevent crashes in limited memory environments
    },
    process_timeout: 10,  # Reduced timeout for faster feedback
    timeout: 5,           # Reduced page timeout
    ignore_https_errors: true
  })
end

# Set the default drivers
Capybara.default_driver = :cuprite
Capybara.javascript_driver = :cuprite
Capybara.current_driver = :cuprite
Capybara.default_max_wait_time = 5

# Load support files
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# Skip migration check temporarily for fixing tests
# begin
#   ActiveRecord::Migration.maintain_test_schema!
# rescue ActiveRecord::PendingMigrationError => e
#   abort e.to_s.strip
# end

# AnyBar helper method
def send_to_anybar(color)
  # Use the method that works reliably
  system("/bin/bash -c 'echo -n \"#{color}\" | nc -4u -w0 localhost 1738'")
rescue => e
  puts "❌ AnyBar error: #{e.message}"
end

RSpec.configure do |config|
  # Include ActiveJob test helpers
  config.include ActiveJob::TestHelper

  config.fixture_paths = [ "#{::Rails.root}/spec/fixtures" ]
  # Transactional fixtures don't work with system tests
  config.use_transactional_fixtures = false

  # Database Cleaner configuration
  config.before(:suite) do
    # Only clean with truncation if not already clean
    if defined?(DatabaseCleaner)
      DatabaseCleaner.clean_with(:truncation, except: %w[ar_internal_metadata schema_migrations])
    end
    # Set AnyBar to black when tests start
    send_to_anybar('black')
  end

  config.before(:each) do |example|
    if example.metadata[:type] == :system || example.metadata[:js]
      # For system tests, use truncation with proper cascade
      DatabaseCleaner.strategy = :truncation, {
        except: %w[ar_internal_metadata schema_migrations],
        pre_count: true,
        cache_tables: false
      }
    else
      DatabaseCleaner.strategy = :transaction
    end
    DatabaseCleaner.start

    # Reset factory sequences to avoid conflicts
    FactoryBot.reload if defined?(FactoryBot)
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  # Ensure database connections are properly managed
  config.after(:each, type: :system) do
    # Force close any lingering connections
    ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connection_pool
  end
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods

  # Include ActiveStorage test helpers
  config.include ActionDispatch::TestProcess::FixtureFile

  # Include Capybara DSL in system tests
  config.include Capybara::DSL, type: :system

  # Consolidated system test setup
  config.before(:each, type: :system) do
    # Use cuprite driver for system tests
    driven_by :cuprite

    # Set default URL options to handle optional locale in routes
    Rails.application.routes.default_url_options[:locale] = nil
  end

  # Helper to set location cookies after visiting a page
  config.before(:each, type: :system) do |example|
    # Don't automatically visit root - let tests handle their own navigation
    # Cookies will be set after the first visit in each test
  end

  # Include Devise test helpers
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :system

  # Configure URL helpers for system tests with optional locale
  config.include Rails.application.routes.url_helpers, type: :system
  config.include SystemHelpers, type: :system
  config.include LocationHelpers, type: :system

  # Configure routing for request specs to handle locale routing
  config.before(:each, type: :request) do
    Rails.application.routes.default_url_options[:locale] = nil
  end


  # AnyBar integration moved to before(:suite) with DatabaseCleaner

  config.after(:suite) do
    if RSpec.configuration.reporter.failed_examples.empty?
      # All tests passed - set AnyBar to green
      send_to_anybar('green')
    #      `osascript -e 'display notification "All tests passed! ✅" with title "RSpec"'`
    else
      # Some tests failed - set AnyBar to red
      send_to_anybar('red')
      #      failed_count = RSpec.configuration.reporter.failed_examples.count
      #      `osascript -e 'display notification "#{failed_count} tests failed ❌" with title "RSpec"'`
    end
  end
end
