require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
abort("Rails is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'capybara/rails'
require 'capybara/cuprite'

$VERBOSE = nil if Rails.env.test?

# Configure Capybara for system tests
Capybara.register_driver :cuprite do |app|
  Capybara::Cuprite::Driver.new(app, {
    window_size: [1200, 800],
    inspector: true,
    headless: !ENV['HEADLESS'].in?(['n', 'no', 'false'])
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
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

# AnyBar helper method
def send_to_anybar(color)
  # Use the method that works reliably
  system("/bin/bash -c 'echo -n \"#{color}\" | nc -4u -w0 localhost 1738'")
rescue => e
  puts "❌ AnyBar error: #{e.message}"
end

RSpec.configure do |config|

  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  
  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods
  
  # Include Capybara DSL in system tests
  config.include Capybara::DSL, type: :system
  
  # Ensure system tests use Cuprite driver
  config.before(:each, type: :system) do
    driven_by :cuprite
  end
  
  # Include Devise test helpers
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :system

  # AnyBar integration
  config.before(:suite) do
    # Set AnyBar to black when tests start
    send_to_anybar('black')
  end

  config.after(:suite) do
    if RSpec.configuration.reporter.failed_examples.empty?
      # All tests passed - set AnyBar to green
      send_to_anybar('green')
      `osascript -e 'display notification "All tests passed! ✅" with title "RSpec"'`
    else
      # Some tests failed - set AnyBar to red
      send_to_anybar('red')
      failed_count = RSpec.configuration.reporter.failed_examples.count
      `osascript -e 'display notification "#{failed_count} tests failed ❌" with title "RSpec"'`
    end
  end

end
