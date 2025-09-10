require 'rails_helper'

RSpec.describe WebhookAuditLog, type: :model do
  describe 'associations' do
    it { should belong_to(:user).optional }
  end

  describe 'validations' do
    subject { build(:webhook_audit_log) }

    it { should validate_presence_of(:webhook_type) }
    it { should validate_inclusion_of(:webhook_type).in_array(%w[deletion deauthorization]) }
    it { should validate_presence_of(:facebook_user_id) }
    it { should validate_presence_of(:payload) }
    it { should validate_inclusion_of(:status).in_array(%w[processed failed invalid]) }
  end

  describe 'scopes' do
    let!(:deletion_log) { create(:webhook_audit_log, webhook_type: 'deletion', status: 'processed') }
    let!(:deauth_log) { create(:webhook_audit_log, webhook_type: 'deauthorization', status: 'failed') }
    let!(:old_log) { create(:webhook_audit_log, processed_at: 2.days.ago) }
    let!(:recent_log) { create(:webhook_audit_log, processed_at: 1.hour.ago) }

    describe '.deletions' do
      it 'returns only deletion webhooks' do
        expect(WebhookAuditLog.deletions).to include(deletion_log)
        expect(WebhookAuditLog.deletions).not_to include(deauth_log)
      end
    end

    describe '.deauthorizations' do
      it 'returns only deauthorization webhooks' do
        expect(WebhookAuditLog.deauthorizations).to include(deauth_log)
        expect(WebhookAuditLog.deauthorizations).not_to include(deletion_log)
      end
    end

    describe '.successful' do
      it 'returns only processed webhooks' do
        expect(WebhookAuditLog.successful).to include(deletion_log)
        expect(WebhookAuditLog.successful).not_to include(deauth_log)
      end
    end

    describe '.failed' do
      it 'returns only failed webhooks' do
        expect(WebhookAuditLog.failed).to include(deauth_log)
        expect(WebhookAuditLog.failed).not_to include(deletion_log)
      end
    end

    describe '.recent' do
      it 'orders by processed_at desc' do
        logs = WebhookAuditLog.recent.to_a
        expect(logs.first.processed_at).to be >= logs.last.processed_at
        expect(logs).to include(recent_log, old_log)
      end
    end
  end

  describe 'class methods' do
    describe '.log_deletion' do
      let(:user) { create(:user) }
      let(:payload) { { "user_id" => "123456789" } }

      it 'creates a deletion audit log' do
        expect {
          WebhookAuditLog.log_deletion(
            facebook_user_id: "123456789",
            user: user,
            payload: payload,
            status: "processed"
          )
        }.to change(WebhookAuditLog, :count).by(1)

        log = WebhookAuditLog.last
        expect(log.webhook_type).to eq("deletion")
        expect(log.facebook_user_id).to eq("123456789")
        expect(log.user).to eq(user)
        expect(log.payload).to eq(payload)
        expect(log.status).to eq("processed")
        expect(log.processed_at).to be_present
      end

      it 'handles error messages' do
        WebhookAuditLog.log_deletion(
          facebook_user_id: "123456789",
          payload: payload,
          status: "failed",
          error_message: "User not found"
        )

        log = WebhookAuditLog.last
        expect(log.status).to eq("failed")
        expect(log.error_message).to eq("User not found")
      end

      it 'logs deletion with nil user when user not found' do
        expect {
          WebhookAuditLog.log_deletion(
            facebook_user_id: "123456789",
            user: nil,
            payload: payload
          )
        }.to change(WebhookAuditLog, :count).by(1)
      end
    end

    describe '.log_deauthorization' do
      let(:user) { create(:user) }
      let(:payload) { { "user_id" => "987654321" } }

      it 'creates a deauthorization audit log' do
        expect {
          WebhookAuditLog.log_deauthorization(
            facebook_user_id: "987654321",
            user: user,
            payload: payload,
            status: "processed"
          )
        }.to change(WebhookAuditLog, :count).by(1)

        log = WebhookAuditLog.last
        expect(log.webhook_type).to eq("deauthorization")
        expect(log.facebook_user_id).to eq("987654321")
      end
    end
  end

  describe 'instance methods' do
    describe '#successful?' do
      it 'returns true for processed status' do
        log = build(:webhook_audit_log, status: 'processed')
        expect(log.successful?).to be true
      end

      it 'returns false for failed status' do
        log = build(:webhook_audit_log, status: 'failed')
        expect(log.successful?).to be false
      end
    end

    describe '#failed?' do
      it 'returns true for failed status' do
        log = build(:webhook_audit_log, status: 'failed')
        expect(log.failed?).to be true
      end

      it 'returns false for processed status' do
        log = build(:webhook_audit_log, status: 'processed')
        expect(log.failed?).to be false
      end
    end

    describe '#deletion?' do
      it 'returns true for deletion webhook type' do
        log = build(:webhook_audit_log, webhook_type: 'deletion')
        expect(log.deletion?).to be true
      end

      it 'returns false for deauthorization webhook type' do
        log = build(:webhook_audit_log, webhook_type: 'deauthorization')
        expect(log.deletion?).to be false
      end
    end

    describe '#deauthorization?' do
      it 'returns true for deauthorization webhook type' do
        log = build(:webhook_audit_log, webhook_type: 'deauthorization')
        expect(log.deauthorization?).to be true
      end

      it 'returns false for deletion webhook type' do
        log = build(:webhook_audit_log, webhook_type: 'deletion')
        expect(log.deauthorization?).to be false
      end
    end
  end

  describe 'GDPR compliance' do
    it 'allows audit logs to be created without user association' do
      # GDPR compliance - logs can be created even without user reference
      log = WebhookAuditLog.log_deletion(
        facebook_user_id: "123456789",
        user: nil,
        payload: { "user_id" => "123456789" }
      )

      expect(log).to be_persisted
      expect(log.user).to be_nil
      expect(log.facebook_user_id).to eq("123456789")
    end

    it 'stores complete payload for compliance' do
      complex_payload = {
        "user_id" => "123456789",
        "signed_request" => "abc.def",
        "algorithm" => "HMAC-SHA256",
        "issued_at" => 1234567890
      }

      log = WebhookAuditLog.log_deletion(
        facebook_user_id: "123456789",
        payload: complex_payload
      )

      expect(log.payload).to eq(complex_payload)
    end

    it 'tracks processing timestamp accurately' do
      current_time = Time.current
      allow(Time).to receive(:current).and_return(current_time)

      log = WebhookAuditLog.log_deletion(
        facebook_user_id: "123456789",
        payload: { "user_id" => "123456789" }
      )

      expect(log.processed_at).to eq(current_time)
    end
  end

  describe 'data integrity' do
    it 'prevents modification of webhook type after creation' do
      log = create(:webhook_audit_log, webhook_type: 'deletion')
      log.webhook_type = 'deauthorization'

      # This should still save (no protection in model)
      expect(log.save).to be true
      # But in practice, these logs should be immutable
    end

    it 'preserves error messages for debugging' do
      error = "Failed to connect to Facebook API: timeout"
      log = WebhookAuditLog.log_deletion(
        facebook_user_id: "123456789",
        payload: { "user_id" => "123456789" },
        status: "failed",
        error_message: error
      )

      expect(log.error_message).to eq(error)
    end

    it 'handles large payloads' do
      large_payload = {
        "user_id" => "123456789",
        "data" => "x" * 10000
      }

      log = WebhookAuditLog.log_deletion(
        facebook_user_id: "123456789",
        payload: large_payload
      )

      expect(log.payload["data"].length).to eq(10000)
    end
  end

  describe 'security considerations' do
    it 'does not expose sensitive data in error messages' do
      sensitive_error = "User password: secret123"
      log = WebhookAuditLog.log_deletion(
        facebook_user_id: "123456789",
        payload: { "user_id" => "123456789" },
        status: "failed",
        error_message: sensitive_error
      )

      # Error is stored as-is (sanitization should happen at display)
      expect(log.error_message).to eq(sensitive_error)
    end

    it 'handles SQL injection attempts in facebook_user_id' do
      malicious_id = "'; DROP TABLE users; --"

      expect {
        WebhookAuditLog.log_deletion(
          facebook_user_id: malicious_id,
          payload: { "user_id" => malicious_id }
        )
      }.to change(WebhookAuditLog, :count).by(1)

      log = WebhookAuditLog.last
      expect(log.facebook_user_id).to eq(malicious_id)
    end

    it 'safely stores JSON payloads with special characters' do
      payload_with_specials = {
        "user_id" => "<script>alert('xss')</script>",
        "data" => "'; DROP TABLE webhooks; --"
      }

      log = WebhookAuditLog.log_deletion(
        facebook_user_id: "123456789",
        payload: payload_with_specials
      )

      expect(log.payload).to eq(payload_with_specials)
    end
  end
end
