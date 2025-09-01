class OnboardingController < ApplicationController
  before_action :check_puppeteer_bypass
  
  def index
    # Clean onboarding page for setting home location
  end

  private

  def check_puppeteer_bypass
    if puppeteer_request?
      Rails.logger.info "[PUPPETEER BACKDOOR] Bypassing onboarding, redirecting to root"
      set_puppeteer_location_in_session
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