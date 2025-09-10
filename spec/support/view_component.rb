require "view_component/test_helpers"
require "capybara/rspec"

RSpec.configure do |config|
  config.include ViewComponent::TestHelpers, type: :component
  config.include Capybara::RSpecMatchers, type: :component

  # ViewComponent tests don't need Devise controller helpers
  config.before(:each, type: :component) do
    # Mock the request object that Devise expects
    @request = double('request', env: {})

    # Create a minimal controller instance for ViewComponent rendering
    @controller = ApplicationController.new
    @controller.request = @request if @controller.respond_to?(:request=)
  end
end
