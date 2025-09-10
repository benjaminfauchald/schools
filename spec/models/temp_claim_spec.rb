require 'rails_helper'

RSpec.describe TempClaim, type: :model do
  let(:school) { create(:school) }
  let(:temp_claim) { create(:temp_claim, school: school) }

  describe 'associations' do
    it { should belong_to(:school) }
  end

  describe 'validations' do
    subject { build(:temp_claim, school: school) }

    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:token) }
    it { should validate_presence_of(:ip_address) }

    it 'validates email format' do
      temp_claim = build(:temp_claim, school: school, email: 'invalid-email')
      expect(temp_claim).not_to be_valid
      expect(temp_claim.errors[:email]).to include('is invalid')

      temp_claim.email = 'valid@example.com'
      expect(temp_claim).to be_valid
    end

    it 'validates status inclusion' do
      valid_statuses = %w[pending_registration registered expired]
      valid_statuses.each do |status|
        temp_claim = build(:temp_claim, school: school, status: status)
        expect(temp_claim).to be_valid
      end

      temp_claim = build(:temp_claim, school: school, status: 'invalid')
      expect(temp_claim).not_to be_valid
      expect(temp_claim.errors[:status]).to include('is not included in the list')
    end
  end

  describe 'scopes' do
    let!(:active_claim) { create(:temp_claim, school: school, expires_at: 1.hour.from_now) }
    let!(:expired_claim) { create(:temp_claim, school: school, expires_at: 1.hour.ago) }
    let!(:pending_claim) { create(:temp_claim, school: school, status: 'pending_registration') }
    let!(:registered_claim) { create(:temp_claim, school: school, status: 'registered') }
    let!(:old_claim) { create(:temp_claim, school: school, created_at: 35.days.ago) }
    let!(:old_registered) { create(:temp_claim, school: school, status: 'registered', updated_at: 10.days.ago) }

    describe '.active' do
      it 'returns claims not yet expired' do
        expect(TempClaim.active).to include(active_claim)
        expect(TempClaim.active).not_to include(expired_claim)
      end
    end

    describe '.expired' do
      it 'returns expired claims' do
        expect(TempClaim.expired).to include(expired_claim)
        expect(TempClaim.expired).not_to include(active_claim)
      end
    end

    describe '.pending_registration' do
      it 'returns pending claims' do
        expect(TempClaim.pending_registration).to include(pending_claim)
        expect(TempClaim.pending_registration).not_to include(registered_claim)
      end
    end

    describe '.registered' do
      it 'returns registered claims' do
        expect(TempClaim.registered).to include(registered_claim)
        expect(TempClaim.registered).not_to include(pending_claim)
      end
    end

    describe '.stale' do
      it 'returns old claims' do
        expect(TempClaim.stale(30)).to include(old_claim)
        expect(TempClaim.stale(30)).not_to include(active_claim)
      end
    end

    describe '.old_registered' do
      it 'returns old registered claims' do
        # Ensure the test data is set up with explicit timestamps to avoid flakiness
        old_registered.update!(updated_at: 8.days.ago) # Explicitly older than 7 days
        registered_claim.update!(updated_at: 1.day.ago) # Explicitly newer than 7 days
        
        expect(TempClaim.old_registered(7)).to include(old_registered)
        expect(TempClaim.old_registered(7)).not_to include(registered_claim)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_validation on create' do
      it 'generates token' do
        claim = TempClaim.new(school: school, email: 'test@example.com', ip_address: '127.0.0.1')
        claim.valid?
        expect(claim.token).to be_present
        expect(claim.token.length).to be >= 32
      end

      it 'sets expiry to 24 hours from now' do
        claim = TempClaim.create!(school: school, email: 'test@example.com', ip_address: '127.0.0.1')
        expect(claim.expires_at).to be_within(1.minute).of(24.hours.from_now)
      end

      it 'does not override existing token' do
        claim = TempClaim.new(school: school, email: 'test@example.com', ip_address: '127.0.0.1', token: 'custom-token')
        claim.valid?
        expect(claim.token).to eq('custom-token')
      end
    end
  end

  describe 'instance methods' do
    describe '#expired?' do
      it 'returns true when expires_at is in the past' do
        temp_claim.expires_at = 1.hour.ago
        expect(temp_claim.expired?).to be true
      end

      it 'returns false when expires_at is in the future' do
        temp_claim.expires_at = 1.hour.from_now
        expect(temp_claim.expired?).to be false
      end
    end

    describe '#active?' do
      it 'returns true when not expired' do
        temp_claim.expires_at = 1.hour.from_now
        expect(temp_claim.active?).to be true
      end

      it 'returns false when expired' do
        temp_claim.expires_at = 1.hour.ago
        expect(temp_claim.active?).to be false
      end
    end

    describe '#pending_registration?' do
      it 'returns true for pending_registration status' do
        temp_claim.status = 'pending_registration'
        expect(temp_claim.pending_registration?).to be true
      end

      it 'returns false for other statuses' do
        temp_claim.status = 'registered'
        expect(temp_claim.pending_registration?).to be false
      end
    end

    describe '#registered?' do
      it 'returns true for registered status' do
        temp_claim.status = 'registered'
        expect(temp_claim.registered?).to be true
      end

      it 'returns false for other statuses' do
        temp_claim.status = 'pending_registration'
        expect(temp_claim.registered?).to be false
      end
    end

    describe '#mark_as_registered!' do
      it 'updates status to registered' do
        temp_claim.status = 'pending_registration'
        temp_claim.mark_as_registered!
        expect(temp_claim.reload.status).to eq('registered')
      end
    end

    describe '#mark_as_expired!' do
      it 'updates status to expired' do
        temp_claim.status = 'pending_registration'
        temp_claim.mark_as_expired!
        expect(temp_claim.reload.status).to eq('expired')
      end
    end
  end

  describe 'class methods' do
    describe '.cleanup_expired!' do
      it 'marks expired claims as expired' do
        active = create(:temp_claim, school: school, expires_at: 1.hour.from_now, status: 'pending_registration')
        expired = create(:temp_claim, school: school, expires_at: 1.hour.ago, status: 'pending_registration')

        TempClaim.cleanup_expired!

        expect(active.reload.status).to eq('pending_registration')
        expect(expired.reload.status).to eq('expired')
      end
    end
  end

  describe 'factory' do
    it 'creates valid temp claim' do
      claim = build(:temp_claim, school: school)
      expect(claim).to be_valid
    end

    it 'generates unique tokens' do
      claim1 = create(:temp_claim, school: school)
      claim2 = create(:temp_claim, school: school)
      expect(claim1.token).not_to eq(claim2.token)
    end
  end
end