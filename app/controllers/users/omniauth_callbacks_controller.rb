class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: [ :facebook, :failure, :mock_facebook, :sync_status ]

  def facebook
    Rails.logger.info "🔵 Facebook OAuth: Callback received"
    Rails.logger.info "🔵 Facebook OAuth: Request headers: #{request.headers.select { |k, _| k.match(/^HTTP.*/) }.to_h}"
    Rails.logger.info "🔵 Facebook OAuth: Request origin: #{request.origin}"
    Rails.logger.info "🔵 Facebook OAuth: Request referer: #{request.referer}"

    auth_hash = request.env["omniauth.auth"]
    Rails.logger.info "🔵 Facebook OAuth: Auth hash present: #{auth_hash.present?}"

    if auth_hash
      Rails.logger.info "🔵 Facebook OAuth: Provider: #{auth_hash.provider}"
      Rails.logger.info "🔵 Facebook OAuth: UID: #{auth_hash.uid}"
      Rails.logger.info "🔵 Facebook OAuth: Name: #{auth_hash.info&.name}"
      Rails.logger.info "🔵 Facebook OAuth: Email: #{auth_hash.info&.email}"
    else
      Rails.logger.error "❌ Facebook OAuth: No auth hash found in request.env"
      Rails.logger.error "❌ Facebook OAuth: Request env keys: #{request.env.keys.select { |k| k.include?('omniauth') }}"
    end

    @user = User.from_omniauth(auth_hash)
    Rails.logger.info "🔵 Facebook OAuth: User from_omniauth result - persisted: #{@user.persisted?}, errors: #{@user.errors.full_messages}"

    if @user.persisted?
      # Store Facebook access token in session for logout
      session[:facebook_access_token] = auth_hash.credentials.token if auth_hash.credentials

      sign_in @user, event: :authentication

      # Check if user was trying to contact a school before OAuth
      if session[:pending_school_contact]
        school_id = session[:pending_school_contact]
        session.delete(:pending_school_contact)
        # Set flag for JavaScript to auto-submit the form
        flash[:facebook_auth_complete] = true
        redirect_to school_path(school_id), notice: "Successfully signed in with Facebook!"
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
    return redirect_to root_path, alert: "Mock authentication only available in development" unless Rails.env.development?

    # Create mock auth hash directly
    mock_auth = OpenStruct.new({
      provider: "facebook",
      uid: "mock_facebook_user",
      info: OpenStruct.new({
        name: "Benjamin Fauchald",
        email: "benjamin@example.com",
        image: "https://graph.facebook.com/mock_facebook_user/picture?type=normal"  # Mock Facebook profile image
      }),
      credentials: OpenStruct.new({
        token: "mock_access_token",
        expires_at: Time.current + 2.months
      }),
      extra: OpenStruct.new({
        raw_info: {
          id: "mock_facebook_user",
          name: "Benjamin Fauchald",
          email: "benjamin@example.com"
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
        # Set flag for JavaScript to auto-submit the form
        flash[:facebook_auth_complete] = true
        redirect_to school_path(id: school_id), notice: "Successfully signed in as Benjamin Fauchald (Mock)!"
      else
        # Default redirect after mock Facebook OAuth
        redirect_to root_path, notice: "Successfully signed in as Benjamin Fauchald (Mock Facebook)!"
      end
    else
      redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
    end
  end

  def failure
    Rails.logger.error "❌ Facebook OAuth: Authentication failed"
    Rails.logger.error "❌ Facebook OAuth: Failure reason: #{params[:message]}"
    Rails.logger.error "❌ Facebook OAuth: Failure strategy: #{params[:strategy]}"
    Rails.logger.error "❌ Facebook OAuth: Request params: #{params.inspect}"
    Rails.logger.error "❌ Facebook OAuth: Request env omniauth.error: #{request.env['omniauth.error']}"
    Rails.logger.error "❌ Facebook OAuth: Request env omniauth.error.type: #{request.env['omniauth.error.type']}"

    error_message = case params[:message]
    when "invalid_credentials"
      "Invalid Facebook credentials. Please try again."
    when "timeout"
      "Facebook authentication timed out. Please try again."
    when "access_denied"
      "You denied access to your Facebook account."
    else
      "Facebook authentication failed (#{params[:message]}). Please try again."
    end

    redirect_to root_path, alert: error_message
  end

  def store_school
    if params[:school_id].present?
      session[:pending_school_contact] = params[:school_id]
      render json: { success: true }
    else
      render json: { success: false }, status: :bad_request
    end
  end

  # Sync Facebook login status from JavaScript SDK
  def sync_status
    Rails.logger.info "Facebook sync_status called with params: #{params.inspect}"

    # Sanitize all input parameters to prevent XSS - strip ALL HTML tags
    facebook_user_id = params[:facebook_user_id].to_s.gsub(/[^a-zA-Z0-9_-]/, "") if params[:facebook_user_id].present?
    access_token = params[:access_token]
    name = ActionController::Base.helpers.strip_tags(params[:name].to_s) if params[:name].present?
    picture_url = params[:picture_url]

    # We don't use email from Facebook anymore - only name and picture
    Rails.logger.info "Facebook sync parsed data: user_id=#{facebook_user_id}, name=#{name}"

    if facebook_user_id.present?
      # Find or create user based on Facebook ID
      user = User.find_by(provider: "facebook", uid: facebook_user_id)

      if user
        # Update existing user's information with sanitized data
        user.update!(
          facebook_name: name,
          facebook_profile_picture_url: picture_url
        ) if name.present?

        # Sign in the user if not already signed in
        unless user_signed_in? && current_user == user
          sign_in user, event: :authentication
        end

        render json: { success: true, user_id: user.id }
      else
        # Create new user with placeholder email
        # Real email will be collected through contact form
        placeholder_email = "fb_#{facebook_user_id}@facebook.local"

        new_user = User.create!(
          email: placeholder_email,
          provider: "facebook",
          uid: facebook_user_id,
          facebook_name: name,
          facebook_profile_picture_url: picture_url,
          role: "school_owner",
          confirmed_at: Time.current,
          password: Devise.friendly_token[0, 20]
        )
        sign_in new_user, event: :authentication
        render json: { success: true, user_id: new_user.id, created: true }
      end
    else
      render json: { success: false, error: "Missing Facebook user ID" }, status: :bad_request
    end
  rescue StandardError => e
    Rails.logger.error "Facebook sync error: #{e.message}"
    render json: { success: false, error: "Sync failed" }, status: :internal_server_error
  end
end
