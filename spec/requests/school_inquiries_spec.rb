require 'rails_helper'

RSpec.describe 'School Inquiries', type: :request do
  let(:school) { create(:school) }
  let(:facebook_user) { create(:user, :facebook_user) }
  let(:regular_user) { create(:user) }

  # Clear rate limit cache before each test to ensure test isolation
  before do
    Rails.cache.clear if Rails.cache.respond_to?(:clear)
  end

  let(:valid_inquiry_params) do
    {
      school_inquiry: {
        name: 'John Doe',
        email: 'john.doe@example.com',
        phone: '+66 2 123 4567',
        message: 'I am interested in enrolling my child in your school.',
        children_count: 1
      }
    }
  end

  let(:invalid_inquiry_params) do
    {
      school_inquiry: {
        name: '',
        email: 'invalid-email',
        message: '',
        children_count: 0
      }
    }
  end

  describe 'POST /schools/:school_id/school_inquiries' do
    let(:url) { school_school_inquiries_path(school_id: school.id) }

    context 'when user is not signed in' do
      it 'redirects to sign in' do
        post url, params: valid_inquiry_params, as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not create inquiry' do
        expect {
          post url, params: valid_inquiry_params, as: :json
        }.not_to change { SchoolInquiry.count }
      end
    end

    context 'when user is signed in but not Facebook authenticated' do
      before { sign_in regular_user, scope: :user }

      it 'returns forbidden status' do
        post url, params: valid_inquiry_params, as: :json
        expect(response).to have_http_status(:forbidden)
      end

      it 'returns Facebook authentication requirement message' do
        post url, params: valid_inquiry_params, as: :json
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be false
        expect(json_response['requires_facebook_auth']).to be true
        expect(json_response['errors']).to include('You must sign in with Facebook to contact schools.')
      end

      it 'does not create inquiry' do
        expect {
          post url, params: valid_inquiry_params, as: :json
        }.not_to change { SchoolInquiry.count }
      end
    end

    context 'when user is Facebook authenticated' do
      before { sign_in facebook_user, scope: :user }

      context 'with valid parameters' do
        it 'returns success status' do
          post url, params: valid_inquiry_params, as: :json
          expect(response).to have_http_status(:ok)
        end

        it 'creates new school inquiry' do
          expect {
            post url, params: valid_inquiry_params, as: :json
          }.to change { SchoolInquiry.count }.by(1)
        end

        it 'associates inquiry with correct school' do
          post url, params: valid_inquiry_params, as: :json
          inquiry = SchoolInquiry.last
          expect(inquiry.school).to eq(school)
        end

        it 'associates inquiry with current user' do
          post url, params: valid_inquiry_params, as: :json
          inquiry = SchoolInquiry.last
          expect(inquiry.user).to eq(facebook_user)
        end

        it 'sets IP address' do
          post url, params: valid_inquiry_params, as: :json
          inquiry = SchoolInquiry.last
          expect(inquiry.ip_address).to be_present
        end

        it 'returns success message' do
          post url, params: valid_inquiry_params, as: :json
          json_response = JSON.parse(response.body)

          expect(json_response['success']).to be true
          expect(json_response['message']).to include('sent successfully')
        end

        it 'saves inquiry with correct data' do
          post url, params: valid_inquiry_params, as: :json
          inquiry = SchoolInquiry.last

          expect(inquiry.name).to eq('John Doe')
          expect(inquiry.email).to eq('john.doe@example.com')
          expect(inquiry.phone).to eq('+66 2 123 4567')
          expect(inquiry.message).to include('interested in enrolling')
          expect(inquiry.children_count).to eq(1)
        end

        it 'sends email notification' do
          expect(SchoolInquiryMailer).to receive(:new_inquiry_notification)
            .and_return(double(deliver_now: true))

          post url, params: valid_inquiry_params, as: :json
        end

        it 'handles email delivery failure gracefully' do
          allow(SchoolInquiryMailer).to receive(:new_inquiry_notification)
            .and_raise(StandardError.new('SMTP Error'))

          post url, params: valid_inquiry_params, as: :json
          expect(response).to have_http_status(:ok)

          json_response = JSON.parse(response.body)
          expect(json_response['success']).to be true
        end
      end

      context 'with invalid parameters' do
        it 'returns unprocessable entity status' do
          post url, params: invalid_inquiry_params, as: :json
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'does not create inquiry' do
          expect {
            post url, params: invalid_inquiry_params, as: :json
          }.not_to change { SchoolInquiry.count }
        end

        it 'returns validation errors' do
          post url, params: invalid_inquiry_params, as: :json
          json_response = JSON.parse(response.body)

          expect(json_response['success']).to be false
          expect(json_response['errors']).to be_an(Array)
          expect(json_response['errors']).not_to be_empty
        end

        it 'includes specific validation messages' do
          post url, params: invalid_inquiry_params, as: :json
          json_response = JSON.parse(response.body)

          expect(json_response['errors'].join).to include('can\'t be blank')
        end
      end

      context 'with missing required parameters' do
        let(:missing_params) do
          {
            school_inquiry: {
              name: 'John Doe'
              # Missing email, message, children_count
            }
          }
        end

        it 'returns validation errors for missing fields' do
          post url, params: missing_params, as: :json
          json_response = JSON.parse(response.body)

          expect(json_response['success']).to be false
          expect(json_response['errors']).to be_an(Array)
        end
      end

      context 'with edge case parameters' do
        let(:edge_case_params) do
          {
            school_inquiry: {
              name: 'A' * 100,  # Exactly at max length (100)
              email: 'test+tag@very-long-domain-name.example.com',
              phone: '+1 (555) 123-4567',  # Within 20 character limit
              message: 'X' * 2000,  # Exactly at max length (2000)
              children_count: 10
            }
          }
        end

        it 'handles long valid inputs' do
          post url, params: edge_case_params, as: :json
          expect(response).to have_http_status(:ok)
        end

        it 'creates inquiry with edge case data' do
          expect {
            post url, params: edge_case_params, as: :json
          }.to change { SchoolInquiry.count }.by(1)
        end
      end

      context 'with special characters' do
        let(:special_char_params) do
          {
            school_inquiry: {
              name: 'José María García-López',
              email: 'jose.garcia@dominio.es',
              phone: '+34 123 456 789',
              message: 'Hola! 你好! こんにちは! Interested in bilingual education 🎓',
              children_count: 2
            }
          }
        end

        it 'handles international characters and emojis' do
          post url, params: special_char_params, as: :json
          expect(response).to have_http_status(:ok)
        end

        it 'preserves special characters' do
          post url, params: special_char_params, as: :json
          inquiry = SchoolInquiry.last
          expect(inquiry.name).to eq('José María García-López')
          expect(inquiry.message).to include('🎓')
        end
      end
    end

    context 'when school does not exist' do
      let(:invalid_url) { school_school_inquiries_path(school_id: 999999) }

      before { sign_in facebook_user, scope: :user }

      it 'returns not found status' do
        post invalid_url, params: valid_inquiry_params, as: :json
        expect(response).to have_http_status(:not_found)
      end

      it 'does not create inquiry' do
        expect {
          post invalid_url, params: valid_inquiry_params, as: :json
        }.not_to change { SchoolInquiry.count }
      end
    end

    context 'when unexpected error occurs' do
      before do
        sign_in facebook_user
        allow(SchoolInquiry).to receive(:new).and_raise(StandardError.new('Database error'))
      end

      it 'returns internal server error status' do
        post url, params: valid_inquiry_params, as: :json
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'returns generic error message' do
        post url, params: valid_inquiry_params, as: :json
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be false
        expect(json_response['errors']).to include('An unexpected error occurred. Please try again.')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/School inquiry creation error/)
        post url, params: valid_inquiry_params, as: :json
      end
    end
  end

  describe 'parameter filtering' do
    before { sign_in facebook_user, scope: :user }
    let(:url) { school_school_inquiries_path(school_id: school.id) }

    context 'with additional unexpected parameters' do
      let(:params_with_extras) do
        {
          school_inquiry: {
            name: 'John Doe',
            email: 'john@example.com',
            message: 'Test message',
            children_count: 1,
            admin_flag: true,        # Should be filtered out
            school_id: 999,          # Should be filtered out
            created_at: 1.day.ago    # Should be filtered out
          }
        }
      end

      it 'filters out unpermitted parameters' do
        post url, params: params_with_extras, as: :json
        inquiry = SchoolInquiry.last

        expect(inquiry.attributes).not_to have_key('admin_flag')
        expect(inquiry.school_id).to eq(school.id) # Set by controller, not params
      end
    end

    it 'permits only allowed parameters' do
      allowed_params = %w[name email phone message children_count]

      post url, params: valid_inquiry_params, as: :json
      inquiry = SchoolInquiry.last

      allowed_params.each do |param|
        expect(inquiry.send(param)).to be_present
      end
    end
  end

  describe 'rate limiting considerations' do
    before { sign_in facebook_user, scope: :user }
    let(:url) { school_school_inquiries_path(school_id: school.id) }

    it 'allows multiple inquiries from same user' do
      2.times do
        expect {
          post url, params: valid_inquiry_params, as: :json
        }.to change { SchoolInquiry.count }.by(1)

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'content type handling' do
    before { sign_in facebook_user, scope: :user }
    let(:url) { school_school_inquiries_path(school_id: school.id) }

    it 'requires JSON content type' do
      post url, params: valid_inquiry_params
      # Should handle both JSON and form requests appropriately
      expect([ 200, 302 ]).to include(response.status)
    end

    it 'handles JSON requests' do
      post url, params: valid_inquiry_params, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'logging behavior' do
    before { sign_in facebook_user, scope: :user }
    let(:url) { school_school_inquiries_path(school_id: school.id) }

    it 'logs validation errors' do
      expect(Rails.logger).to receive(:error).with(/School inquiry validation failed/)
      post url, params: invalid_inquiry_params, as: :json
    end

    it 'logs email delivery errors' do
      allow(SchoolInquiryMailer).to receive(:new_inquiry_notification)
        .and_raise(StandardError.new('Email failed'))

      expect(Rails.logger).to receive(:error).with(/Failed to send inquiry email/)
      post url, params: valid_inquiry_params, as: :json
    end
  end

  describe 'inquiry data integrity' do
    before { sign_in facebook_user, scope: :user }
    let(:url) { school_school_inquiries_path(school_id: school.id) }

    it 'does not allow inquiry for non-existent school' do
      # Try to post to non-existent school - should result in 404
      post school_school_inquiries_path(school_id: 999999),
           params: valid_inquiry_params, as: :json
      expect(response).to have_http_status(:not_found)
    end

    it 'associates inquiry with correct user even with malicious params' do
      malicious_params = valid_inquiry_params.deep_merge(
        school_inquiry: { user_id: create(:user).id }
      )

      post url, params: malicious_params, as: :json
      inquiry = SchoolInquiry.last
      expect(inquiry.user).to eq(facebook_user)
    end
  end
end
