class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [:create]
  before_action :configure_account_update_params, only: [:update]
  
  protected

  # Override Devise's create method to handle temp claims
  def create
    super do |resource|
      if resource.persisted? && session[:temp_claim_token].present?
        # Process the temp claim after successful registration
        if resource.process_temp_claim!(session[:temp_claim_token])
          session.delete(:temp_claim_token)
          # Set a flash message that will be shown after email confirmation
          session[:post_confirmation_message] = 'Your school claim has been submitted for approval!'
        end
      end
    end
  end

  # Override the after_sign_up_path to redirect to appropriate page
  def after_sign_up_path_for(resource)
    if session[:temp_claim_token].present?
      # If there's still a temp claim token, something went wrong
      session.delete(:temp_claim_token)
    end
    
    # Check if user has pending claims to show appropriate message
    if resource.school_claims.pending.any?
      school_owner_dashboard_index_path
    else
      root_path
    end
  end

  # Override inactive sign up path for email confirmation
  def after_inactive_sign_up_path_for(resource)
    # Show a custom message if they have a temp claim
    if resource.school_claims.any?
      new_user_session_path
    else
      super
    end
  end

  private

  # Permit additional parameters for temp claims
  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [])
  end

  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [])
  end
end