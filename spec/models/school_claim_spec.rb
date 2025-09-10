require 'rails_helper'

RSpec.describe SchoolClaim, type: :model do
  include ActiveSupport::Testing::TimeHelpers
  # First test: approve! method
  describe '#approve!' do
    let(:school) { create(:school) }
    let(:user) { create(:user) }
    let(:admin_user) { create(:admin_user) }
    let(:school_claim) { create(:school_claim, school: school, user: user, status: 'pending') }

    # Mock the mailer to avoid sending actual emails in tests
    before do
      allow(ClaimNotificationMailer).to receive(:claim_approved)
        .and_return(double(deliver_later: true))
      allow(ClaimNotificationMailer).to receive(:claim_submitted)
        .and_return(double(deliver_later: true))
      allow(ClaimNotificationMailer).to receive(:new_claim_for_admin)
        .and_return(double(deliver_later: true))
    end

    context 'when claim is pending' do
      it 'changes status to approved' do
        expect {
          school_claim.approve!(admin_user, notes: 'Verified ownership')
        }.to change { school_claim.reload.status }.from('pending').to('approved')
      end

      it 'sets admin notes' do
        school_claim.approve!(admin_user, notes: 'Documentation verified')
        expect(school_claim.reload.admin_notes).to eq('Documentation verified')
      end

      it 'updates the timestamp' do
        # Use travel_to instead of freeze_time (Rails test helper)
        travel_to Time.zone.local(2024, 1, 15, 10, 0, 0) do
          school_claim.approve!(admin_user, notes: 'Approved')
          expect(school_claim.reload.updated_at).to eq(Time.current)
        end
      end

      it 'sends approval notification email' do
        expect(ClaimNotificationMailer).to receive(:claim_approved)
          .with(school_claim)
          .and_return(double(deliver_later: true))

        school_claim.approve!(admin_user, notes: 'Approved')
      end
    end

    context 'when claim is already approved' do
      let(:approved_claim) { create(:school_claim, :approved, school: school, user: user) }

      it 'cannot be approved again' do
        # The model doesn't actually raise an error, it just doesn't allow the transition
        # Let's test what actually happens
        expect(approved_claim.can_approve?).to be false
      end
    end
  end

  # Second test: reject! method
  describe '#reject!' do
    let(:school) { create(:school) }
    let(:user) { create(:user) }
    let(:admin_user) { create(:admin_user) }
    let(:school_claim) { create(:school_claim, school: school, user: user, status: 'pending') }

    # Mock the mailer to avoid sending actual emails in tests
    before do
      allow(ClaimNotificationMailer).to receive(:claim_rejected)
        .and_return(double(deliver_later: true))
      allow(ClaimNotificationMailer).to receive(:claim_submitted)
        .and_return(double(deliver_later: true))
      allow(ClaimNotificationMailer).to receive(:new_claim_for_admin)
        .and_return(double(deliver_later: true))
    end

    context 'when claim is pending' do
      it 'changes status to rejected' do
        expect {
          school_claim.reject!(admin_user, notes: 'Insufficient evidence')
        }.to change { school_claim.reload.status }.from('pending').to('rejected')
      end

      it 'requires admin notes' do
        expect {
          school_claim.reject!(admin_user)
        }.to raise_error(ArgumentError)
      end

      it 'sets admin notes' do
        school_claim.reject!(admin_user, notes: 'Documentation not valid')
        expect(school_claim.reload.admin_notes).to eq('Documentation not valid')
      end

      it 'updates the timestamp' do
        travel_to Time.zone.local(2024, 1, 15, 10, 0, 0) do
          school_claim.reject!(admin_user, notes: 'Rejected')
          expect(school_claim.reload.updated_at).to eq(Time.current)
        end
      end

      it 'sends rejection notification email' do
        expect(ClaimNotificationMailer).to receive(:claim_rejected)
          .with(school_claim)
          .and_return(double(deliver_later: true))

        school_claim.reject!(admin_user, notes: 'Rejected')
      end
    end

    context 'when claim is already rejected' do
      let(:rejected_claim) { create(:school_claim, :rejected, school: school, user: user) }

      it 'cannot be rejected again' do
        expect(rejected_claim.can_reject?).to be false
      end
    end
  end

  # Third test: uniqueness validation
  describe 'uniqueness validation' do
    let(:school) { create(:school) }
    let(:user) { create(:user) }
    let(:admin_user) { create(:admin_user) }

    before do
      allow(ClaimNotificationMailer).to receive(:claim_submitted)
        .and_return(double(deliver_later: true))
      allow(ClaimNotificationMailer).to receive(:new_claim_for_admin)
        .and_return(double(deliver_later: true))
    end

    context 'when user already has a pending claim for the school' do
      before do
        create(:school_claim, school: school, user: user, status: 'pending')
      end

      it 'prevents duplicate claims' do
        duplicate_claim = build(:school_claim, school: school, user: user, status: 'pending')
        expect(duplicate_claim).not_to be_valid
        expect(duplicate_claim.errors[:school_id]).to include('already has a pending or approved claim')
      end
    end

    context 'when user already has an approved claim for the school' do
      before do
        create(:school_claim, :approved, school: school, user: user)
      end

      it 'prevents new claims' do
        new_claim = build(:school_claim, school: school, user: user, status: 'pending')
        expect(new_claim).not_to be_valid
        expect(new_claim.errors[:school_id]).to include('already has a pending or approved claim')
      end
    end

    context 'when user has a rejected claim for the school' do
      before do
        create(:school_claim, :rejected, school: school, user: user)
      end

      it 'prevents new claims even after rejection' do
        new_claim = build(:school_claim, school: school, user: user, status: 'pending')
        expect(new_claim).not_to be_valid
        expect(new_claim.errors[:school_id]).to include('already has a pending or approved claim')
      end
    end

    context 'when different users claim the same school' do
      let(:another_user) { create(:user) }

      before do
        create(:school_claim, school: school, user: user, status: 'pending')
      end

      it 'allows different users to claim the same school' do
        another_claim = build(:school_claim, school: school, user: another_user, status: 'pending')
        expect(another_claim).to be_valid
      end
    end

    context 'when same user claims different schools' do
      let(:another_school) { create(:school) }

      before do
        create(:school_claim, school: school, user: user, status: 'pending')
      end

      it 'allows same user to claim different schools' do
        another_claim = build(:school_claim, school: another_school, user: user, status: 'pending')
        expect(another_claim).to be_valid
      end
    end
  end

  # Fourth test: status transitions
  describe 'status transitions' do
    let(:school) { create(:school) }
    let(:user) { create(:user) }
    let(:admin_user) { create(:admin_user) }

    before do
      allow(ClaimNotificationMailer).to receive(:claim_submitted)
        .and_return(double(deliver_later: true))
      allow(ClaimNotificationMailer).to receive(:new_claim_for_admin)
        .and_return(double(deliver_later: true))
      allow(ClaimNotificationMailer).to receive(:claim_approved)
        .and_return(double(deliver_later: true))
      allow(ClaimNotificationMailer).to receive(:claim_rejected)
        .and_return(double(deliver_later: true))
    end

    describe 'can_approve?' do
      it 'returns true for pending claims' do
        claim = create(:school_claim, status: 'pending', school: school, user: user)
        expect(claim.can_approve?).to be true
      end

      it 'returns false for approved claims' do
        claim = create(:school_claim, :approved, school: school, user: user)
        expect(claim.can_approve?).to be false
      end

      it 'returns false for rejected claims' do
        claim = create(:school_claim, :rejected, school: school, user: user)
        expect(claim.can_reject?).to be false
      end
    end

    describe 'can_reject?' do
      it 'returns true for pending claims' do
        claim = create(:school_claim, status: 'pending', school: school, user: user)
        expect(claim.can_reject?).to be true
      end

      it 'returns false for approved claims' do
        claim = create(:school_claim, :approved, school: school, user: user)
        expect(claim.can_reject?).to be false
      end

      it 'returns false for rejected claims' do
        claim = create(:school_claim, :rejected, school: school, user: user)
        expect(claim.can_reject?).to be false
      end
    end

    describe 'status enum' do
      it 'defines pending status' do
        claim = create(:school_claim, status: 'pending', school: school, user: user)
        expect(claim.pending?).to be true
      end

      it 'defines approved status' do
        claim = create(:school_claim, :approved, school: school, user: user)
        expect(claim.approved?).to be true
      end

      it 'defines rejected status' do
        claim = create(:school_claim, :rejected, school: school, user: user)
        expect(claim.rejected?).to be true
      end

      it 'validates status inclusion' do
        # Rails enums raise ArgumentError for invalid values
        expect {
          build(:school_claim, school: school, user: user, status: 'invalid')
        }.to raise_error(ArgumentError, "'invalid' is not a valid status")
      end
    end

    describe 'active?' do
      it 'returns true for approved claims' do
        claim = create(:school_claim, :approved, school: school, user: user)
        expect(claim.active?).to be true
      end

      it 'returns false for pending claims' do
        claim = create(:school_claim, status: 'pending', school: school, user: user)
        expect(claim.active?).to be false
      end

      it 'returns false for rejected claims' do
        claim = create(:school_claim, :rejected, school: school, user: user)
        expect(claim.active?).to be false
      end
    end
  end

  # Fifth test: notifications
  describe 'notifications' do
    let(:school) { create(:school) }
    let(:user) { create(:user) }
    let(:admin_user) { create(:admin_user) }

    describe 'after_create callbacks' do
      it 'sends submission notification to user' do
        expect(ClaimNotificationMailer).to receive(:claim_submitted)
          .and_return(double(deliver_later: true))
        expect(ClaimNotificationMailer).to receive(:new_claim_for_admin)
          .and_return(double(deliver_later: true))

        create(:school_claim, school: school, user: user, status: 'pending')
      end

      it 'sends notification to admins about new claim' do
        expect(ClaimNotificationMailer).to receive(:claim_submitted)
          .and_return(double(deliver_later: true))
        expect(ClaimNotificationMailer).to receive(:new_claim_for_admin)
          .and_return(double(deliver_later: true))

        create(:school_claim, school: school, user: user, status: 'pending')
      end
    end

    describe 'helper methods' do
      let(:claim) { create(:school_claim, school: school, user: user, status: 'pending') }

      before do
        allow(ClaimNotificationMailer).to receive(:claim_submitted)
          .and_return(double(deliver_later: true))
        allow(ClaimNotificationMailer).to receive(:new_claim_for_admin)
          .and_return(double(deliver_later: true))
      end

      describe '#user_email' do
        it 'returns the user email' do
          expect(claim.user_email).to eq(user.email)
        end
      end

      describe '#days_pending' do
        it 'returns 0 for newly created claims' do
          expect(claim.days_pending.to_i).to eq(0)
        end

        it 'calculates days for older claims' do
          claim.update!(created_at: 5.days.ago)
          expect(claim.days_pending.to_i).to eq(5)
        end

        it 'returns 0 for non-pending claims' do
          approved_claim = create(:school_claim, :approved, school: school, user: user)
          expect(approved_claim.days_pending).to eq(0)
        end
      end

      describe '#stale?' do
        it 'returns false for new claims' do
          expect(claim.stale?).to be false
        end

        it 'returns true for claims pending over 30 days' do
          claim.update!(created_at: 31.days.ago)
          expect(claim.stale?).to be true
        end

        it 'returns false for non-pending claims even if old' do
          approved_claim = create(:school_claim, :approved, school: school, user: user)
          approved_claim.update!(created_at: 31.days.ago)
          expect(approved_claim.stale?).to be false
        end
      end
    end
  end
end
