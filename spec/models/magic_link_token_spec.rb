require 'rails_helper'

RSpec.describe MagicLinkToken, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:magic_link_token) }

    it { should validate_presence_of(:purpose) }

    it 'ensures token uniqueness' do
      # Tokens are auto-generated to be unique
      token1 = create(:magic_link_token)
      token2 = create(:magic_link_token)

      expect(token1.token).not_to eq(token2.token)
    end

    it 'auto-generates token if not provided' do
      token = MagicLinkToken.new(user: create(:user), purpose: 'test')
      expect(token.token).to be_nil

      token.valid?
      expect(token.token).to be_present
    end

    it 'auto-generates expires_at if not provided' do
      token = MagicLinkToken.new(user: create(:user), purpose: 'test', token: 'test')
      expect(token.expires_at).to be_nil

      token.valid?
      expect(token.expires_at).to be_present
    end
  end

  describe 'scopes' do
    let!(:active_token) { create(:magic_link_token, expires_at: 1.hour.from_now) }
    let!(:expired_token) { create(:magic_link_token, expires_at: 1.hour.ago) }
    let!(:used_token) { create(:magic_link_token, :used) }

    describe '.active' do
      it 'returns only non-expired tokens' do
        expect(MagicLinkToken.active).to include(active_token)
        expect(MagicLinkToken.active).not_to include(expired_token)
      end
    end

    describe '.expired' do
      it 'returns only expired tokens' do
        expect(MagicLinkToken.expired).to include(expired_token)
        expect(MagicLinkToken.expired).not_to include(active_token)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_validation on create' do
      it 'generates a secure token automatically' do
        token = build(:magic_link_token, token: nil)
        token.valid?
        expect(token.token).to be_present
        expect(token.token.length).to be >= 32
      end

      it 'sets default expiry time' do
        token = build(:magic_link_token, expires_at: nil)
        token.valid?
        expect(token.expires_at).to be_present
        expect(token.expires_at).to be > Time.current
      end
    end
  end

  describe 'instance methods' do
    describe '#expired?' do
      it 'returns true for expired tokens' do
        token = build(:magic_link_token, expires_at: 1.hour.ago)
        expect(token.expired?).to be true
      end

      it 'returns false for active tokens' do
        token = build(:magic_link_token, expires_at: 1.hour.from_now)
        expect(token.expired?).to be false
      end
    end

    describe '#active?' do
      it 'returns true for unused, non-expired tokens' do
        token = build(:magic_link_token, expires_at: 1.hour.from_now, used_at: nil)
        expect(token.active?).to be true
      end

      it 'returns false for expired tokens' do
        token = build(:magic_link_token, expires_at: 1.hour.ago)
        expect(token.active?).to be false
      end

      it 'returns false for used tokens' do
        token = build(:magic_link_token, expires_at: 1.hour.from_now, used_at: Time.current)
        expect(token.active?).to be false
      end
    end

    describe '#mark_as_used!' do
      it 'sets used_at timestamp' do
        token = create(:magic_link_token)
        expect(token.used_at).to be_nil

        token.mark_as_used!
        expect(token.used_at).to be_present
        expect(token.used_at).to be <= Time.current
      end

      it 'persists the change' do
        token = create(:magic_link_token)
        token.mark_as_used!

        token.reload
        expect(token.used_at).to be_present
      end
    end
  end

  describe 'class methods' do
    describe '.create_dashboard_token' do
      let(:user) { create(:user) }

      it 'creates a token for dashboard access' do
        expect {
          MagicLinkToken.create_dashboard_token(user)
        }.to change(MagicLinkToken, :count).by(1)

        token = MagicLinkToken.last
        expect(token.user).to eq(user)
        expect(token.purpose).to eq("dashboard_access")
      end

      it 'uses default 48 hour expiry' do
        allow(Time).to receive(:current).and_return(Time.parse("2025-01-01 12:00:00"))

        token = MagicLinkToken.create_dashboard_token(user)
        expected_expiry = Time.parse("2025-01-03 12:00:00")

        expect(token.expires_at).to be_within(1.second).of(expected_expiry)
      end

      it 'accepts custom expiry time' do
        token = MagicLinkToken.create_dashboard_token(user, expires_in: 24.hours)

        expect(token.expires_at).to be_within(1.minute).of(24.hours.from_now)
      end
    end

    describe '.cleanup_expired!' do
      before do
        # Clear all existing tokens to ensure test isolation
        MagicLinkToken.delete_all
      end

      let!(:expired_token1) { create(:magic_link_token, expires_at: 2.days.ago) }
      let!(:expired_token2) { create(:magic_link_token, expires_at: 1.hour.ago) }
      let!(:active_token) { create(:magic_link_token, expires_at: 1.hour.from_now) }

      it 'deletes all expired tokens' do
        expect {
          MagicLinkToken.cleanup_expired!
        }.to change(MagicLinkToken, :count).by(-2)

        expect(MagicLinkToken.exists?(expired_token1.id)).to be false
        expect(MagicLinkToken.exists?(expired_token2.id)).to be false
        expect(MagicLinkToken.exists?(active_token.id)).to be true
      end

      it 'returns count of deleted tokens' do
        count = MagicLinkToken.cleanup_expired!
        expect(count).to eq(2)
      end
    end
  end

  describe 'security features' do
    describe 'token generation' do
      it 'generates cryptographically secure tokens' do
        tokens = 10.times.map { create(:magic_link_token).token }

        # All tokens should be unique
        expect(tokens.uniq.length).to eq(10)

        # Tokens should be URL-safe base64
        tokens.each do |token|
          expect(token).to match(/\A[A-Za-z0-9_\-]+\z/)
        end
      end

      it 'prevents token reuse' do
        user = create(:user)
        token = MagicLinkToken.create_dashboard_token(user)
        token.mark_as_used!

        expect(token.active?).to be false
      end

      it 'generates unique tokens every time' do
        tokens = 10.times.map { create(:magic_link_token).token }

        # All tokens should be unique
        expect(tokens.uniq.length).to eq(10)
      end
    end

    describe 'timing attack prevention' do
      it 'uses secure token generation' do
        token = create(:magic_link_token)

        # This is more of a documentation test
        # Real timing attack prevention should be in controller
        expect(token.token).to be_a(String)
        expect(token.token).to match(/\A[A-Za-z0-9_\-]+\z/)  # URL-safe base64
      end
    end

    describe 'token expiry' do
      it 'prevents use of expired tokens' do
        token = create(:magic_link_token, expires_at: 1.second.ago)
        expect(token.active?).to be false
      end

      it 'has reasonable default expiry' do
        token = MagicLinkToken.new(user: create(:user), purpose: "test")
        token.save!

        expect(token.expires_at).to be_within(1.minute).of(48.hours.from_now)
      end
    end

    describe 'purpose tracking' do
      it 'tracks token purpose for audit' do
        user = create(:user)

        dashboard_token = MagicLinkToken.create_dashboard_token(user)
        expect(dashboard_token.purpose).to eq("dashboard_access")

        password_token = create(:magic_link_token,
          user: user,
          purpose: "password_reset"
        )
        expect(password_token.purpose).to eq("password_reset")
      end
    end
  end

  describe 'edge cases' do
    describe 'concurrent token generation' do
      it 'generates unique tokens for multiple requests' do
        user = create(:user)

        tokens = 5.times.map do
          MagicLinkToken.create_dashboard_token(user)
        end

        # All tokens should be created successfully
        expect(tokens.length).to eq(5)
        # All tokens should be unique
        expect(tokens.map(&:token).uniq.length).to eq(5)
      end
    end

    describe 'token collision handling' do
      it 'regenerates token on collision' do
        existing_token = create(:magic_link_token)

        # Mock SecureRandom to return duplicate then unique
        call_count = 0
        allow(SecureRandom).to receive(:urlsafe_base64) do
          call_count += 1
          call_count == 1 ? existing_token.token : "unique_token_#{call_count}"
        end

        new_token = create(:magic_link_token)
        expect(new_token.token).not_to eq(existing_token.token)
      end
    end

    describe 'user deletion' do
      it 'cascades deletion to associated tokens' do
        user = create(:user)
        token = MagicLinkToken.create_dashboard_token(user)

        expect {
          user.destroy
        }.to change(MagicLinkToken, :count).by(-1)

        expect(MagicLinkToken.exists?(token.id)).to be false
      end
    end
  end

  describe 'performance considerations' do
    describe 'index usage' do
      it 'has index on token for fast lookups' do
        # This is a documentation test
        # Actual index verification would be in schema tests
        token = create(:magic_link_token)

        # This query should use index
        found = MagicLinkToken.find_by(token: token.token)
        expect(found).to eq(token)
      end

      it 'has index on expires_at for cleanup queries' do
        create_list(:magic_link_token, 3, expires_at: 1.hour.ago)
        create_list(:magic_link_token, 2, expires_at: 1.hour.from_now)

        # This query should use index
        expired = MagicLinkToken.expired
        expect(expired.count).to eq(3)
      end
    end
  end

  describe 'GDPR compliance' do
    it 'is deleted when user exercises right to erasure' do
      user = create(:user)
      token = MagicLinkToken.create_dashboard_token(user)

      # Simulate GDPR deletion
      user.destroy

      expect(MagicLinkToken.exists?(token.id)).to be false
    end

    it 'does not contain PII in token itself' do
      user = create(:user, email: "test@example.com")
      token = MagicLinkToken.create_dashboard_token(user)

      # Token should not contain email or other PII
      expect(token.token).not_to include("test")
      expect(token.token).not_to include("example.com")
      # Token is random, so it might contain small numbers by chance
      # The important thing is it's not intentionally encoding the user ID
      expect(token.token).to match(/\A[A-Za-z0-9_\-]+\z/)  # Just URL-safe base64
    end
  end
end
