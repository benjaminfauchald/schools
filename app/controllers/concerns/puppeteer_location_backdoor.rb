# Simple Puppeteer detection for testing
module PuppeteerLocationBackdoor
  extend ActiveSupport::Concern

  private

  # Detect if request is from Puppeteer or other headless browser
  def puppeteer_request?
    return false if Rails.env.production? # Never enable in production

    user_agent = request.headers["User-Agent"].to_s.downcase

    # Common Puppeteer/headless browser indicators
    user_agent.include?("headlesschrome") ||
    user_agent.include?("puppeteer") ||
    user_agent.include?("playwright") ||
    user_agent.include?("selenium") ||
    user_agent.include?("phantomjs") ||
    # Chrome headless mode
    (user_agent.include?("chrome") && user_agent.include?("headless"))
  end
end
