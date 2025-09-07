class MagicLinksController < ApplicationController
  def dashboard
    token = params[:token]

    unless token.present?
      redirect_to new_user_session_path, alert: "Invalid or missing authentication token."
      return
    end

    magic_token = MagicLinkToken.find_by(token: token)

    unless magic_token
      redirect_to new_user_session_path, alert: "Invalid authentication token."
      return
    end

    unless magic_token.active?
      redirect_to new_user_session_path, alert: "Authentication token has expired or been used."
      return
    end

    unless magic_token.purpose == "dashboard_access"
      redirect_to new_user_session_path, alert: "Invalid token purpose."
      return
    end

    # Token is valid - authenticate the user
    user = magic_token.user

    # Mark token as used (one-time use only)
    magic_token.mark_as_used!

    # Sign in the user
    sign_in(user)

    # Set success message
    flash[:notice] = "Welcome back! You've been automatically signed in."

    # Redirect to dashboard
    if user.school_owner?
      redirect_to school_owner_dashboard_index_path
    else
      redirect_to root_path
    end
  end

  private

  def authenticate_user!
    # Skip normal authentication for magic links
  end
end
