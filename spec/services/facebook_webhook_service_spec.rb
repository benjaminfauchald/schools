require 'rails_helper'

RSpec.describe FacebookWebhookService, type: :service do
  describe '#initialize' do
    it 'parses JSON string payload' do
      json_string = '{"user_id":"123456"}'
      service = described_class.new(json_string)
      expect(service.instance_variable_get(:@payload)).to eq({ 'user_id' => '123456' })
    end

    it 'handles hash payload directly' do
      hash_payload = { 'user_id' => '123456' }
      service = described_class.new(hash_payload)
      expect(service.instance_variable_get(:@payload)).to eq(hash_payload)
    end

    it 'handles invalid JSON gracefully' do
      invalid_json = 'not valid json'
      service = described_class.new(invalid_json)
      expect(service.instance_variable_get(:@payload)).to eq({})
    end
  end

  describe '#process_deletion_request' do
    # First test: handles valid deletion request
    context 'with valid Facebook user' do
      let(:facebook_user_id) { '123456789' }
      let(:user) { create(:user, :facebook_user, uid: facebook_user_id) }
      let(:payload) { { 'user_id' => facebook_user_id } }
      let(:service) { described_class.new(payload) }

      before do
        user # Create user before test
        allow(WebhookAuditLog).to receive(:log_deletion)
      end

      it 'deletes Facebook data for the user' do
        expect_any_instance_of(User).to receive(:delete_facebook_data!)

        result = service.process_deletion_request

        expect(result[:success]).to be true
        expect(result[:facebook_user_id]).to eq(facebook_user_id)
        expect(result[:user_found]).to be true
      end

      it 'logs successful deletion to audit log' do
        allow_any_instance_of(User).to receive(:delete_facebook_data!)

        expect(WebhookAuditLog).to receive(:log_deletion).with(
          facebook_user_id: facebook_user_id,
          user: user,
          payload: payload,
          status: 'processed'
        )

        service.process_deletion_request
      end
    end

    context 'with non-existent Facebook user' do
      let(:facebook_user_id) { 'nonexistent123' }
      let(:payload) { { 'user_id' => facebook_user_id } }
      let(:service) { described_class.new(payload) }

      before do
        allow(WebhookAuditLog).to receive(:log_deletion)
      end

      it 'still returns success but indicates user not found' do
        result = service.process_deletion_request

        expect(result[:success]).to be true
        expect(result[:facebook_user_id]).to eq(facebook_user_id)
        expect(result[:user_found]).to be false
      end

      it 'logs the deletion request even without user' do
        expect(WebhookAuditLog).to receive(:log_deletion).with(
          facebook_user_id: facebook_user_id,
          user: nil,
          payload: payload,
          status: 'processed'
        )

        service.process_deletion_request
      end
    end

    context 'with missing Facebook user ID' do
      let(:payload) { {} }
      let(:service) { described_class.new(payload) }

      before do
        allow(WebhookAuditLog).to receive(:log_deletion)
      end

      it 'returns failure with error message' do
        result = service.process_deletion_request

        expect(result[:success]).to be false
        expect(result[:error]).to eq('No Facebook user ID found in deletion request payload')
      end

      it 'logs failure to audit log' do
        expect(WebhookAuditLog).to receive(:log_deletion).with(
          facebook_user_id: 'unknown',
          payload: payload,
          status: 'failed',
          error_message: 'No Facebook user ID found in deletion request payload'
        )

        service.process_deletion_request
      end
    end

    context 'when deletion fails' do
      let(:facebook_user_id) { '123456789' }
      let(:user) { create(:user, :facebook_user, uid: facebook_user_id) }
      let(:payload) { { 'user_id' => facebook_user_id } }
      let(:service) { described_class.new(payload) }

      before do
        user
        allow(WebhookAuditLog).to receive(:log_deletion)
        allow_any_instance_of(User).to receive(:delete_facebook_data!).and_raise(StandardError, 'Database error')
      end

      it 'returns failure with error details' do
        result = service.process_deletion_request

        expect(result[:success]).to be false
        expect(result[:error]).to include('Database error')
      end

      it 'logs error to audit log' do
        expect(WebhookAuditLog).to receive(:log_deletion).with(
          facebook_user_id: facebook_user_id,
          user: user,
          payload: payload,
          status: 'failed',
          error_message: 'Failed to process deletion request: Database error'
        )

        service.process_deletion_request
      end
    end

    context 'payload format variations' do
      let(:user) { create(:user, :facebook_user, uid: '123456') }

      before do
        user
        allow(WebhookAuditLog).to receive(:log_deletion)
        allow_any_instance_of(User).to receive(:delete_facebook_data!)
      end

      it 'extracts user_id from standard format' do
        service = described_class.new({ 'user_id' => '123456' })
        result = service.process_deletion_request
        expect(result[:facebook_user_id]).to eq('123456')
      end

      it 'extracts id from alternative format' do
        service = described_class.new({ 'id' => '123456' })
        result = service.process_deletion_request
        expect(result[:facebook_user_id]).to eq('123456')
      end

      it 'extracts nested user.id format' do
        service = described_class.new({ 'user' => { 'id' => '123456' } })
        result = service.process_deletion_request
        expect(result[:facebook_user_id]).to eq('123456')
      end
    end
  end

  describe '#process_deauthorization' do
    context 'with valid Facebook user' do
      let(:facebook_user_id) { '987654321' }
      let(:user) { create(:user, :facebook_user, uid: facebook_user_id) }
      let(:payload) { { 'user_id' => facebook_user_id } }
      let(:service) { described_class.new(payload) }

      before do
        user
        allow(WebhookAuditLog).to receive(:log_deauthorization)
      end

      it 'deauthorizes Facebook for the user' do
        expect_any_instance_of(User).to receive(:deauthorize_facebook!)

        result = service.process_deauthorization

        expect(result[:success]).to be true
        expect(result[:facebook_user_id]).to eq(facebook_user_id)
        expect(result[:user_found]).to be true
      end

      it 'logs successful deauthorization' do
        allow_any_instance_of(User).to receive(:deauthorize_facebook!)

        expect(WebhookAuditLog).to receive(:log_deauthorization).with(
          facebook_user_id: facebook_user_id,
          user: user,
          payload: payload,
          status: 'processed'
        )

        service.process_deauthorization
      end
    end

    context 'with non-existent Facebook user' do
      let(:facebook_user_id) { 'nonexistent456' }
      let(:payload) { { 'user_id' => facebook_user_id } }
      let(:service) { described_class.new(payload) }

      before do
        allow(WebhookAuditLog).to receive(:log_deauthorization)
      end

      it 'still returns success but indicates user not found' do
        result = service.process_deauthorization

        expect(result[:success]).to be true
        expect(result[:facebook_user_id]).to eq(facebook_user_id)
        expect(result[:user_found]).to be false
      end
    end

    context 'with missing Facebook user ID' do
      let(:payload) { {} }
      let(:service) { described_class.new(payload) }

      before do
        allow(WebhookAuditLog).to receive(:log_deauthorization)
      end

      it 'returns failure with error message' do
        result = service.process_deauthorization

        expect(result[:success]).to be false
        expect(result[:error]).to eq('No Facebook user ID found in deauthorization payload')
      end
    end

    context 'when deauthorization fails' do
      let(:facebook_user_id) { '987654321' }
      let(:user) { create(:user, :facebook_user, uid: facebook_user_id) }
      let(:payload) { { 'user_id' => facebook_user_id } }
      let(:service) { described_class.new(payload) }

      before do
        user
        allow(WebhookAuditLog).to receive(:log_deauthorization)
        allow_any_instance_of(User).to receive(:deauthorize_facebook!).and_raise(StandardError, 'Auth error')
      end

      it 'returns failure with error details' do
        result = service.process_deauthorization

        expect(result[:success]).to be false
        expect(result[:error]).to include('Auth error')
      end

      it 'logs error to audit log' do
        expect(WebhookAuditLog).to receive(:log_deauthorization).with(
          facebook_user_id: facebook_user_id,
          user: user,
          payload: payload,
          status: 'failed',
          error_message: 'Failed to process deauthorization: Auth error'
        )

        service.process_deauthorization
      end
    end
  end

  describe 'GDPR compliance' do
    let(:facebook_user_id) { '111222333' }
    let(:user) { create(:user, :facebook_user, uid: facebook_user_id) }
    let(:payload) { { 'user_id' => facebook_user_id } }
    let(:service) { described_class.new(payload) }

    before do
      user
      allow(WebhookAuditLog).to receive(:log_deletion)
      allow(WebhookAuditLog).to receive(:log_deauthorization)
    end

    it 'preserves business records during deletion' do
      # Should delete Facebook data but preserve user account
      expect_any_instance_of(User).to receive(:delete_facebook_data!)
      expect_any_instance_of(User).not_to receive(:destroy)

      service.process_deletion_request
    end

    it 'maintains audit trail for compliance' do
      allow_any_instance_of(User).to receive(:delete_facebook_data!)

      # Should create audit log for compliance
      expect(WebhookAuditLog).to receive(:log_deletion)

      service.process_deletion_request
    end

    it 'handles deletion within GDPR timeframe' do
      # Service should process immediately (synchronously)
      # Not testing actual timing but ensuring synchronous processing
      expect_any_instance_of(User).to receive(:delete_facebook_data!).and_call_original

      start_time = Time.current
      service.process_deletion_request
      processing_time = Time.current - start_time

      # Should process synchronously (quickly)
      expect(processing_time).to be < 1.second
    end
  end
end
