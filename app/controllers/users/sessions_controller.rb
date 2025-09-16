class Users::SessionsController < Devise::SessionsController
  # Override Devise's create action to track logins
  def create
    super do |resource|
      # Clear any Facebook logout flags when signing in again
      cookies.delete(:facebook_logout)

      # Track user login
      if resource
        AnalyticsService.track_login(resource, method: "email")
      end
    end
  end

  # Override Devise's destroy action to handle Facebook logout
  def destroy
    # Check if the user logged in with Facebook
    facebook_user = current_user&.provider == "facebook" if current_user
    facebook_token = session[:facebook_access_token]

    # Store this for the logout message
    was_facebook = facebook_user

    # Sign out from Devise (clears session)
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))

    # Clear ALL session data to ensure complete logout
    reset_session

    if was_facebook
      # Set a cookie to prevent auto-login after logout
      cookies[:facebook_logout] = {
        value: "true",
        expires: 1.hour.from_now,
        httponly: false  # Allow JavaScript to read this
      }

      # For Facebook users, add a flag to trigger client-side Facebook logout
      flash[:notice] = "Signed out successfully. Note: You may still be logged into Facebook. To fully logout, please visit Facebook.com and sign out there as well."
      flash[:facebook_logout] = true

      # Optional: Invalidate the Facebook token server-side
      # This won't log them out of Facebook, but will revoke app permissions
      if facebook_token.present? && ENV["FACEBOOK_APP_ID"].present? && ENV["FACEBOOK_APP_SECRET"].present?
        begin
          # Make a DELETE request to Facebook to revoke the token
          require "net/http"
          require "uri"

          uri = URI("https://graph.facebook.com/v18.0/me/permissions")
          uri.query = URI.encode_www_form({
            access_token: facebook_token
          })

          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          request = Net::HTTP::Delete.new(uri)
          response = http.request(request)

          Rails.logger.info "Facebook token revocation response: #{response.code}"
        rescue => e
          Rails.logger.error "Failed to revoke Facebook token: #{e.message}"
        end
      end

      respond_to_on_destroy
    else
      # Regular logout flow
      flash[:notice] = "Signed out successfully."
      respond_to_on_destroy
    end
  end

  private

  def respond_to_on_destroy
    # Respond to different formats
    respond_to do |format|
      format.all { head :no_content }
      format.any(*navigational_formats) { redirect_to after_sign_out_path_for(resource_name) }
    end
  end
end
