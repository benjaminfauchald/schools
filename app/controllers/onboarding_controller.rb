class OnboardingController < ApplicationController
  def index
    # Clean onboarding page for setting home location
  end
  
  def complete
    # Handle completion of onboarding
    respond_to do |format|
      format.html { redirect_to root_path, notice: 'Welcome! Your home location has been set.' }
      format.json { render json: { status: 'success', redirect_url: root_path } }
    end
  end
end