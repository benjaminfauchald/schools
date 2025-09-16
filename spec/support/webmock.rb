require 'webmock/rspec'

RSpec.configure do |config|
  config.before(:each) do
    # Allow localhost connections for test server
    WebMock.disable_net_connect!(allow_localhost: true)

    # Stub Mixpanel API calls
    stub_request(:post, "https://api.mixpanel.com/track")
      .to_return(status: 200, body: '{"error": null, "status": 1}', headers: { 'Content-Type' => 'application/json' })
  end

  config.after(:each) do
    # Clean up any WebMock stubs after each test
    WebMock.reset!
  end
end
