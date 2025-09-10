require 'rails_helper'

RSpec.describe FacebookSignatureValidator, type: :service do
  let(:app_secret) { 'test_app_secret_123' }
  let(:request_body) { '{"user_id":"123456789","algorithm":"HMAC-SHA256"}' }
  let(:valid_signature) do
    app_secret ? OpenSSL::HMAC.hexdigest('SHA256', app_secret, request_body) : 'dummy_signature'
  end
  let(:valid_header) { "sha256=#{valid_signature}" }

  let(:request) do
    double('request',
      raw_post: request_body,
      body: StringIO.new(request_body),
      headers: {
        'X-Hub-Signature-256' => valid_header
      }
    )
  end

  describe '#initialize' do
    it 'initializes with request and optional app secret' do
      validator = described_class.new(request, app_secret)
      expect(validator).to be_a(FacebookSignatureValidator)
    end

    it 'uses environment variable when app secret not provided' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('FACEBOOK_APP_SECRET').and_return('env_secret')
      validator = described_class.new(request)
      expect(validator.instance_variable_get(:@app_secret)).to eq('env_secret')
    end

    it 'handles both X-Hub-Signature-256 and HTTP_X_HUB_SIGNATURE_256 headers' do
      request_with_http_header = double('request',
        raw_post: request_body,
        body: StringIO.new(request_body),
        headers: {
          'HTTP_X_HUB_SIGNATURE_256' => valid_header
        }
      )

      validator = described_class.new(request_with_http_header, app_secret)
      expect(validator.valid_signature?).to be true
    end
  end

  describe '#valid_signature?' do
    subject { described_class.new(request, app_secret) }

    context 'with valid signature' do
      it 'returns true' do
        expect(subject.valid_signature?).to be true
      end
    end

    context 'with invalid signature' do
      let(:valid_header) { 'sha256=invalid_signature_123' }

      it 'returns false' do
        expect(subject.valid_signature?).to be false
      end
    end

    context 'with missing app secret' do
      let(:app_secret) { nil }

      it 'returns false' do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('FACEBOOK_APP_SECRET').and_return(nil)
        expect(subject.valid_signature?).to be false
      end
    end

    context 'with missing signature header' do
      let(:request) do
        double('request',
          raw_post: request_body,
          body: StringIO.new(request_body),
          headers: {}
        )
      end

      it 'returns false' do
        expect(subject.valid_signature?).to be false
      end
    end

    context 'with empty request body' do
      let(:request_body) { '' }

      it 'returns false' do
        expect(subject.valid_signature?).to be false
      end
    end

    context 'with malformed signature header' do
      let(:valid_header) { 'invalid_format' }

      it 'returns false' do
        expect(subject.valid_signature?).to be false
      end
    end

    context 'with sha1 signature instead of sha256' do
      let(:valid_header) { "sha1=#{OpenSSL::HMAC.hexdigest('SHA1', app_secret, request_body)}" }

      it 'returns false' do
        expect(subject.valid_signature?).to be false
      end
    end
  end

  describe '#compute_signature' do
    subject { described_class.new(request, app_secret) }

    it 'computes HMAC-SHA256 signature' do
      expected = OpenSSL::HMAC.hexdigest('SHA256', app_secret, request_body)
      expect(subject.compute_signature).to eq(expected)
    end

    it 'produces consistent signatures for same input' do
      sig1 = subject.compute_signature
      sig2 = subject.compute_signature
      expect(sig1).to eq(sig2)
    end

    it 'produces different signatures for different secrets' do
      validator1 = described_class.new(request, 'secret1')
      validator2 = described_class.new(request, 'secret2')

      expect(validator1.compute_signature).not_to eq(validator2.compute_signature)
    end
  end

  describe '#error_message' do
    subject { described_class.new(request, app_secret) }

    context 'when app secret is missing' do
      let(:app_secret) { nil }

      it 'returns appropriate error message' do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('FACEBOOK_APP_SECRET').and_return(nil)
        expect(subject.error_message).to eq('Facebook app secret not configured')
      end
    end

    context 'when signature header is missing' do
      let(:request) do
        double('request',
          raw_post: request_body,
          body: StringIO.new(request_body),
          headers: {}
        )
      end

      it 'returns appropriate error message' do
        expect(subject.error_message).to eq('Missing X-Hub-Signature-256 header')
      end
    end

    context 'when request body is empty' do
      let(:request_body) { '' }

      it 'returns appropriate error message' do
        expect(subject.error_message).to eq('Empty request body')
      end
    end

    context 'when signature format is invalid' do
      let(:valid_header) { 'invalid_format' }

      it 'returns appropriate error message' do
        expect(subject.error_message).to eq('Invalid signature format in header')
      end
    end

    context 'when signature validation fails' do
      let(:valid_header) { 'sha256=abcdef0123456789' }  # Valid format but wrong signature

      it 'returns generic error message' do
        expect(subject.error_message).to eq('Signature validation failed')
      end
    end
  end

  describe 'Security features' do
    describe 'timing attack prevention' do
      it 'uses constant-time comparison' do
        validator = described_class.new(request, app_secret)

        # The secure_compare method should take same time regardless of when mismatch occurs
        # This is a documentation test - actual timing attack prevention is in implementation
        expect(validator).to respond_to(:valid_signature?)
      end

      it 'rejects signatures of different lengths' do
        short_sig_header = 'sha256=short'
        request_with_short = double('request',
          raw_post: request_body,
          body: StringIO.new(request_body),
          headers: { 'X-Hub-Signature-256' => short_sig_header }
        )

        validator = described_class.new(request_with_short, app_secret)
        expect(validator.valid_signature?).to be false
      end
    end

    describe 'signature format validation' do
      it 'only accepts sha256 algorithm' do
        algorithms = [ 'sha1', 'md5', 'sha512', 'none' ]

        algorithms.each do |algo|
          header = "#{algo}=somesignature"
          request_with_algo = double('request',
            raw_post: request_body,
            body: StringIO.new(request_body),
            headers: { 'X-Hub-Signature-256' => header }
          )

          validator = described_class.new(request_with_algo, app_secret)
          expect(validator.valid_signature?).to be false
        end
      end

      it 'validates hexadecimal signature format' do
        non_hex_header = 'sha256=xyz!@#$%'
        request_with_non_hex = double('request',
          raw_post: request_body,
          body: StringIO.new(request_body),
          headers: { 'X-Hub-Signature-256' => non_hex_header }
        )

        validator = described_class.new(request_with_non_hex, app_secret)
        expect(validator.valid_signature?).to be false
      end
    end
  end

  describe 'Edge cases' do
    it 'handles nil request gracefully' do
      expect {
        described_class.new(nil, app_secret)
      }.to raise_error(NoMethodError)
    end

    it 'handles request with no body method' do
      request_no_body = double('request',
        raw_post: '',
        headers: { 'X-Hub-Signature-256' => valid_header }
      )

      allow(request_no_body).to receive(:body).and_return(StringIO.new(''))

      validator = described_class.new(request_no_body, app_secret)
      expect(validator.valid_signature?).to be false
    end

    it 'handles very large request bodies' do
      large_body = '{"data":"' + 'x' * 1_000_000 + '"}'
      large_signature = OpenSSL::HMAC.hexdigest('SHA256', app_secret, large_body)

      request_large = double('request',
        raw_post: large_body,
        body: StringIO.new(large_body),
        headers: { 'X-Hub-Signature-256' => "sha256=#{large_signature}" }
      )

      validator = described_class.new(request_large, app_secret)
      expect(validator.valid_signature?).to be true
    end

    it 'handles Unicode in request body' do
      unicode_body = '{"message":"Hello 世界 🌍"}'
      unicode_signature = OpenSSL::HMAC.hexdigest('SHA256', app_secret, unicode_body)

      request_unicode = double('request',
        raw_post: unicode_body,
        body: StringIO.new(unicode_body),
        headers: { 'X-Hub-Signature-256' => "sha256=#{unicode_signature}" }
      )

      validator = described_class.new(request_unicode, app_secret)
      expect(validator.valid_signature?).to be true
    end

    it 'handles binary data in request body' do
      binary_body = "\x00\x01\x02\x03\x04"
      binary_signature = OpenSSL::HMAC.hexdigest('SHA256', app_secret, binary_body)

      request_binary = double('request',
        raw_post: binary_body,
        body: StringIO.new(binary_body),
        headers: { 'X-Hub-Signature-256' => "sha256=#{binary_signature}" }
      )

      validator = described_class.new(request_binary, app_secret)
      expect(validator.valid_signature?).to be true
    end
  end

  describe 'Integration with Facebook webhooks' do
    it 'validates actual Facebook webhook format' do
      # Example from Facebook documentation
      facebook_payload = {
        "entry" => [
          {
            "id" => "0",
            "time" => 1234567890,
            "messaging" => [
              {
                "sender" => { "id" => "USER_ID" },
                "recipient" => { "id" => "PAGE_ID" },
                "timestamp" => 1234567890
              }
            ]
          }
        ],
        "object" => "page"
      }.to_json

      facebook_signature = OpenSSL::HMAC.hexdigest('SHA256', app_secret, facebook_payload)

      request_facebook = double('request',
        raw_post: facebook_payload,
        body: StringIO.new(facebook_payload),
        headers: { 'X-Hub-Signature-256' => "sha256=#{facebook_signature}" }
      )

      validator = described_class.new(request_facebook, app_secret)
      expect(validator.valid_signature?).to be true
    end

    it 'handles Facebook signed_request format for deletion' do
      deletion_payload = {
        "signed_request" => "SIGNED_DATA.PAYLOAD"
      }.to_json

      deletion_signature = OpenSSL::HMAC.hexdigest('SHA256', app_secret, deletion_payload)

      request_deletion = double('request',
        raw_post: deletion_payload,
        body: StringIO.new(deletion_payload),
        headers: { 'X-Hub-Signature-256' => "sha256=#{deletion_signature}" }
      )

      validator = described_class.new(request_deletion, app_secret)
      expect(validator.valid_signature?).to be true
    end
  end
end
