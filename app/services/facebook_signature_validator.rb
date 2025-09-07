class FacebookSignatureValidator
  def initialize(request, app_secret = nil)
    @request = request
    @app_secret = app_secret || ENV["FACEBOOK_APP_SECRET"]
    @body = @request.raw_post || @request.body.read
    @signature_header = @request.headers["X-Hub-Signature-256"] || @request.headers["HTTP_X_HUB_SIGNATURE_256"]
  end

  def valid_signature?
    return false if @app_secret.blank?
    return false if @signature_header.blank?
    return false if @body.blank?

    expected_signature = compute_signature
    signature_from_header = extract_signature_from_header

    return false if signature_from_header.blank?

    # Use secure comparison to prevent timing attacks
    secure_compare(expected_signature, signature_from_header)
  end

  def compute_signature
    OpenSSL::HMAC.hexdigest("SHA256", @app_secret, @body)
  end

  def error_message
    return "Facebook app secret not configured" if @app_secret.blank?
    return "Missing X-Hub-Signature-256 header" if @signature_header.blank?
    return "Empty request body" if @body.blank?
    return "Invalid signature format in header" if extract_signature_from_header.blank?
    "Signature validation failed"
  end

  private

  def extract_signature_from_header
    return nil if @signature_header.blank?

    # Facebook sends signature as "sha256=<actual_signature>"
    match = @signature_header.match(/^sha256=([a-f0-9]+)$/)
    match ? match[1] : nil
  end

  def secure_compare(expected, actual)
    return false if expected.nil? || actual.nil?
    return false unless expected.length == actual.length

    # Constant-time comparison to prevent timing attacks
    result = 0
    expected.bytes.zip(actual.bytes) do |expected_byte, actual_byte|
      result |= expected_byte ^ actual_byte
    end
    result == 0
  end
end
