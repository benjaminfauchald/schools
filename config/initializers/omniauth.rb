OmniAuth.config.allowed_request_methods = [ :post, :get ]
OmniAuth.config.silence_get_warning = true

# Custom failure handler to properly handle CSRF token issues
OmniAuth.config.on_failure = Proc.new do |env|
  # Extract the failure strategy and message
  strategy = env["omniauth.error.strategy"]&.name || "unknown"
  error_type = env["omniauth.error.type"] || "unknown_error"

  # Log the error for debugging
  Rails.logger.error "OmniAuth failure: strategy=#{strategy}, error_type=#{error_type}"

  # Redirect to the Devise OmniAuth failure path
  # This bypasses the normal controller flow that's causing CSRF issues
  message_key = error_type.to_s.gsub("_", "").to_sym
  redirect_path = "/users/auth/facebook/callback?message=#{error_type}"

  # Create a simple redirect response
  [ 302, { "Location" => redirect_path, "Content-Type" => "text/html" }, [ "Redirecting..." ] ]
end
