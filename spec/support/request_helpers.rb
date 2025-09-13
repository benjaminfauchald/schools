module RequestHelpers
  # Parse JSON response
  def json_response
    JSON.parse(response.body)
  rescue JSON::ParserError
    {}
  end

  # Sign in a user for request specs
  def sign_in_user(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: user.password || 'password123'
      }
    }
  end

  # Get auth headers for API requests
  def auth_headers(user)
    user.create_new_auth_token
  end

  # Create headers with authentication
  def authenticated_header(user)
    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json'
    }.merge(auth_headers(user))
  end

  # Create JSON headers
  def json_headers
    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json'
    }
  end

  # Helper to follow redirects in request specs
  def follow_all_redirects!
    while response.status == 302 || response.status == 303
      follow_redirect!
    end
  end

  # Get CSRF token from session
  def csrf_token
    session[:_csrf_token] ||= SecureRandom.base64(32)
  end

  # Check common response attributes
  def expect_success_response
    expect(response).to have_http_status(:success)
    expect(response.content_type).to match(/json/) if response.body.present?
  end

  def expect_unauthorized_response
    expect(response).to have_http_status(:unauthorized)
  end

  def expect_forbidden_response
    expect(response).to have_http_status(:forbidden)
  end

  def expect_not_found_response
    expect(response).to have_http_status(:not_found)
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
