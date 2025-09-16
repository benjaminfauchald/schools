# Mixpanel Analytics Configuration
# This initializer sets up the Mixpanel tracker for server-side event tracking

require "mixpanel-ruby"

# Initialize Mixpanel tracker if token is present
if ENV["MIXPANEL_TOKEN"].present?
  # Use US API endpoint (default) - change to 'https://api-eu.mixpanel.com' if your project is in EU
  Rails.application.config.mixpanel_tracker = Mixpanel::Tracker.new(
    ENV["MIXPANEL_TOKEN"],
    api_host: "https://api.mixpanel.com"
  )

  Rails.logger.info "Mixpanel initialized with project token: #{ENV['MIXPANEL_TOKEN'][0..10]}..."
else
  Rails.logger.warn "Mixpanel token not found - analytics tracking disabled"

  # Create a null tracker for development/test environments without token
  Rails.application.config.mixpanel_tracker = nil
end

# Helper method to safely track events
def track_mixpanel_event(distinct_id, event_name, properties = {})
  return unless Rails.application.config.mixpanel_tracker

  begin
    Rails.application.config.mixpanel_tracker.track(distinct_id, event_name, properties)
  rescue => e
    Rails.logger.error "Mixpanel tracking error: #{e.message}"
  end
end
