class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: [:facebook, :mock_facebook]
  
  def facebook
    @user = User.from_omniauth(request.env["omniauth.auth"])
    
    if @user.persisted?
      sign_in @user, event: :authentication
      
      # Check if user was trying to contact a school before OAuth
      if session[:pending_school_contact]
        school_id = session[:pending_school_contact]
        session.delete(:pending_school_contact)
        redirect_to school_path(school_id), notice: "Successfully signed in with Facebook! You can now send your message to the school."
      else
        # Default redirect after Facebook OAuth
        redirect_to root_path, notice: "Successfully signed in with Facebook!"
      end
    else
      session["devise.facebook_data"] = request.env["omniauth.auth"].except(:extra)
      redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
    end
  end
  
  # Mock Facebook authentication for development
  def mock_facebook
    return redirect_to root_path, alert: 'Mock authentication only available in development' unless Rails.env.development?
    
    # Create mock auth hash directly
    mock_auth = OpenStruct.new({
      provider: 'facebook',
      uid: 'mock_facebook_user',
      info: OpenStruct.new({
        name: 'Benjamin Fauchald',
        email: 'benjamin@example.com',
        image: 'https://avatars.githubusercontent.com/u/12345?v=4'  # Mock profile image
      }),
      credentials: OpenStruct.new({
        token: 'mock_access_token',
        expires_at: Time.current + 2.months
      }),
      extra: OpenStruct.new({
        raw_info: {
          id: 'mock_facebook_user',
          name: 'Benjamin Fauchald',
          email: 'benjamin@example.com'
        }
      })
    })
    
    @user = User.from_omniauth(mock_auth)
    
    if @user.persisted?
      sign_in @user, event: :authentication
      
      # Check if user was trying to contact a school before OAuth
      if session[:pending_school_contact]
        school_id = session[:pending_school_contact]
        session.delete(:pending_school_contact)
        redirect_to school_path(school_id), notice: "Successfully signed in as Benjamin Fauchald (Mock)! You can now send your message to the school."
      else
        # Default redirect after mock Facebook OAuth
        redirect_to root_path, notice: "Successfully signed in as Benjamin Fauchald (Mock Facebook)!"
      end
    else
      redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
    end
  end
  
  def failure
    redirect_to root_path, alert: 'Facebook authentication failed. Please try again.'
  end
  
  def store_school
    if params[:school_id].present?
      session[:pending_school_contact] = params[:school_id]
      render json: { success: true }
    else
      render json: { success: false }, status: :bad_request
    end
  end
end