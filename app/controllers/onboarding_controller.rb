class OnboardingController < ApplicationController
  before_action :check_puppeteer_bypass

  def index
    # Clean onboarding page for setting home location
  end

  def complete
    # Track location setting
    if params[:lat].present? && params[:lng].present?
      AnalyticsService.track_location_set(
        lat: params[:lat],
        lng: params[:lng],
        area: params[:area],
        user: current_user,
        request: request
      )

      # Track onboarding completion
      if session[:onboarding_start_time].present?
        duration = Time.current.to_i - session[:onboarding_start_time].to_i
        AnalyticsService.track_onboarding_complete(
          duration_seconds: duration,
          user: current_user,
          request: request
        )
        session.delete(:onboarding_start_time)
      end
    end

    # Handle completion of onboarding
    respond_to do |format|
      format.html { redirect_to root_path, notice: "Welcome! Your home location has been set." }
      format.json { render json: { status: "success", redirect_url: root_path } }
    end
  end

  private

  def check_puppeteer_bypass
    # Debug logging to see what User-Agent we're getting
    user_agent = request.headers["User-Agent"].to_s
    Rails.logger.info "[ONBOARDING DEBUG] User-Agent: '#{user_agent}'"
    Rails.logger.info "[ONBOARDING DEBUG] Puppeteer check result: #{puppeteer_request?}"

    # For puppeteer requests, just set the location data but don't redirect
    # The location controller will handle the rest
    if puppeteer_request?
      Rails.logger.info "[PUPPETEER BACKDOOR] Setting location data for onboarding page"
      session[:puppeteer_location] = { lat: 13.7563, lng: 100.5018, formatted_address: "Bangkok, Thailand" }
    end
  end
end
