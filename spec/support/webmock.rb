require 'webmock/rspec'

RSpec.configure do |config|
  config.before(:each) do
    # Allow localhost connections for test server
    WebMock.disable_net_connect!(allow_localhost: true)
  end
  
  config.after(:each) do
    # Clean up any WebMock stubs after each test
    WebMock.reset!
  end
end