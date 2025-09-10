module LocationHelpers
  def set_location_cookies
    # Set location cookies to prevent onboarding redirect
    # Per CLAUDE.md: "user has to have location in cookie in order for this solution to work"
    # Using coordinates for Bangkok, Thailand: 13.7563, 100.5018
    page.driver.browser.cookies.set(name: 'location_lat', value: '13.7563', domain: 'localhost')
    page.driver.browser.cookies.set(name: 'location_lng', value: '100.5018', domain: 'localhost')
    page.driver.browser.cookies.set(name: 'location_set', value: 'true', domain: 'localhost')
  rescue => e
    # If cookies can't be set (e.g., no page loaded yet), ignore
    Rails.logger.debug "Could not set location cookies: #{e.message}"
  end

  def visit_with_location(path)
    visit path
    set_location_cookies
    path
  end

  # Override visit for system tests to always set location cookies
  def visit(path)
    # First visit root if we haven't set cookies yet
    unless @location_cookies_set
      super('/')
      set_location_cookies
      @location_cookies_set = true
    end
    # Now visit the actual path
    super(path)
  end
end
