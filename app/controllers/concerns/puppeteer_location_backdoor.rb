# Concern to provide location backdoor for Puppeteer testing
# Automatically provides Bangkok coordinates when headless browser is detected
module PuppeteerLocationBackdoor
  extend ActiveSupport::Concern

  # Central Bangkok coordinates (Siam area)
  BANGKOK_COORDINATES = {
    lat: 13.7563,
    lng: 100.5018,
    formatted_address: "Siam, Pathum Wan, Bangkok 10330, Thailand"
  }.freeze

  private

  # Detect if request is from Puppeteer or other headless browser
  def puppeteer_request?
    return false if Rails.env.production? # Never enable in production
    
    user_agent = request.headers['User-Agent'].to_s.downcase
    
    # Common Puppeteer/headless browser indicators
    user_agent.include?('headlesschrome') ||
    user_agent.include?('puppeteer') ||
    user_agent.include?('playwright') ||
    user_agent.include?('selenium') ||
    user_agent.include?('phantomjs') ||
    # Chrome headless mode
    (user_agent.include?('chrome') && user_agent.include?('headless'))
  end

  # Get location with Puppeteer backdoor support
  def get_location_with_backdoor
    if puppeteer_request?
      Rails.logger.info "[PUPPETEER BACKDOOR] Using Bangkok coordinates for headless browser"
      return BANGKOK_COORDINATES
    end

    # Try to get location from request parameters (normal flow)
    if respond_to?(:get_home_location_from_client, true)
      get_home_location_from_client
    else
      nil
    end
  end

  # Set Puppeteer location in session for JavaScript access
  def set_puppeteer_location_in_session
    if puppeteer_request?
      session[:puppeteer_location] = BANGKOK_COORDINATES
      Rails.logger.info "[PUPPETEER BACKDOOR] Set Bangkok coordinates in session"
    end
  end
end