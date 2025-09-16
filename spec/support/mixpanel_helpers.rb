# Helper methods for stubbing Mixpanel API calls in tests
module MixpanelHelpers
  def stub_mixpanel_requests!
    # Stub tracking requests
    stub_request(:post, "https://api.mixpanel.com/track")
      .to_return(status: 200, body: "1", headers: {})

    # Stub people/engage requests for user identification
    stub_request(:post, "https://api.mixpanel.com/engage")
      .to_return(status: 200, body: "1", headers: {})

    # Stub EU endpoints as well (in case we switch)
    stub_request(:post, "https://api-eu.mixpanel.com/track")
      .to_return(status: 200, body: "1", headers: {})

    stub_request(:post, "https://api-eu.mixpanel.com/engage")
      .to_return(status: 200, body: "1", headers: {})
  end

  # Mock the Mixpanel tracker to prevent any real API calls
  def mock_mixpanel_tracker!
    tracker = instance_double(Mixpanel::Tracker)
    people = instance_double(Mixpanel::People)

    allow(tracker).to receive(:track).and_return(true)
    allow(tracker).to receive(:alias).and_return(true)
    allow(tracker).to receive(:people).and_return(people)
    allow(people).to receive(:set).and_return(true)

    allow(Rails.application.config).to receive(:mixpanel_tracker).and_return(tracker)
  end

  # Disable Mixpanel tracking entirely
  def disable_mixpanel!
    allow(Rails.application.config).to receive(:mixpanel_tracker).and_return(nil)
  end
end

RSpec.configure do |config|
  config.include MixpanelHelpers

  # Automatically stub Mixpanel for all tests
  config.before(:each) do
    stub_mixpanel_requests!
  end
end
