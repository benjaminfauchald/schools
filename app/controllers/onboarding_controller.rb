class OnboardingController < ApplicationController
  before_action :check_puppeteer_bypass
  
  def index
    # Clean onboarding page for setting home location
  end

  private

  def check_puppeteer_bypass
    # Debug logging to see what User-Agent we're getting
    user_agent = request.headers['User-Agent'].to_s
    Rails.logger.info "[ONBOARDING DEBUG] User-Agent: '#{user_agent}'"
    Rails.logger.info "[ONBOARDING DEBUG] Puppeteer check result: #{puppeteer_request?}"
    
    if puppeteer_request?
      Rails.logger.info "[PUPPETEER BACKDOOR] Bypassing onboarding, redirecting to root"
      # Set session data so JavaScript can find it
      session[:puppeteer_location] = { lat: 13.6983415, lng: 100.5260653 }
      redirect_to root_path
    end
  end
  
  def complete
    # Handle completion of onboarding
    respond_to do |format|
      format.html { redirect_to root_path, notice: 'Welcome! Your home location has been set.' }
      format.json { render json: { status: 'success', redirect_url: root_path } }
    end
  end
end