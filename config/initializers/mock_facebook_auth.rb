# Mock Facebook Authentication for Development
# This provides a fake Facebook OAuth response when Facebook API is not available

if Rails.env.development?
  # Add mock auth data structure (available globally)
  class MockFacebookAuth
    def self.create_mock_auth_hash
      OpenStruct.new({
        provider: "facebook",
        uid: "mock_facebook_user",
        info: OpenStruct.new({
          name: "Benjamin Fauchald",
          email: "benjamin@example.com",
          image: "https://avatars.githubusercontent.com/u/12345?v=4"  # Mock profile image
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
    end
  end

  Rails.application.config.to_prepare do
    # Store original method first
    User.class_eval do
      class << self
        alias_method :original_from_omniauth, :from_omniauth unless method_defined?(:original_from_omniauth)
      end
    end

    # Override the from_omniauth method to use mock data in development
    User.class_eval do
      def self.from_omniauth(auth)
        # Check if this is a mock auth request (when Facebook API is down)
        if auth.provider == "facebook" && auth.uid == "mock_facebook_user"
          # Try to find existing mock user
          user = User.find_by(provider: "facebook", uid: "mock_facebook_user")

          if user
            # Update Facebook name if it's different
            user.update(facebook_name: auth.info.name) if user.facebook_name != auth.info.name
            return user
          end

          # Try to find existing user by email
          user = User.find_by(email: auth.info.email)

          if user
            # Link this OAuth account to existing user
            user.update!(
              provider: auth.provider,
              uid: auth.uid,
              facebook_name: auth.info.name
            )
            return user
          end

          # Create new mock Facebook user
          User.create!(
            email: auth.info.email,
            provider: auth.provider,
            uid: auth.uid,
            facebook_name: auth.info.name,
            role: "school_owner",
            confirmed_at: Time.current,
            password: Devise.friendly_token[0, 20]
          )
        else
          # Use the original from_omniauth logic for real Facebook auth if it exists
          if respond_to?(:original_from_omniauth)
            original_from_omniauth(auth)
          else
            # Fallback implementation for real Facebook auth
            user = User.find_by(provider: auth.provider, uid: auth.uid)

            if user
              # Update Facebook name if it's different
              user.update(facebook_name: auth.info.name) if user.facebook_name != auth.info.name
              return user
            end

            # Try to find existing user by email
            user = User.find_by(email: auth.info.email)

            if user
              # Link this OAuth account to existing user
              user.update!(
                provider: auth.provider,
                uid: auth.uid,
                facebook_name: auth.info.name
              )
              return user
            end

            # Create new Facebook user
            User.create!(
              email: auth.info.email,
              provider: auth.provider,
              uid: auth.uid,
              facebook_name: auth.info.name,
              role: "school_owner",
              confirmed_at: Time.current,
              password: Devise.friendly_token[0, 20]
            )
          end
        end
      end
    end
  end
end
