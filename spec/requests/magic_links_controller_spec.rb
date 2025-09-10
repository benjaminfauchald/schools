require 'rails_helper'

RSpec.describe MagicLinksController, type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe 'GET /auth/dashboard/:token' do
    let(:user) { create(:user) }

    # First test: non-existent token
    context 'with non-existent token' do
      it 'redirects to sign in with error' do
        get magic_link_dashboard_path(token: 'non_existent_token')

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to eq('Invalid authentication token.')
      end
    end

    # Second test: expired token
    context 'with expired token' do
      it 'redirects to sign in with error' do
        expired_token = MagicLinkToken.create_dashboard_token(user)
        expired_token.update!(expires_at: 1.hour.ago)

        get magic_link_dashboard_path(token: expired_token.token)

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to eq('Authentication token has expired or been used.')
      end
    end

    # Third test: already used token
    context 'with already used token' do
      it 'redirects to sign in with error' do
        used_token = MagicLinkToken.create_dashboard_token(user)
        used_token.mark_as_used!

        get magic_link_dashboard_path(token: used_token.token)

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to eq('Authentication token has expired or been used.')
      end
    end

    # Fourth test: wrong purpose token
    context 'with wrong purpose token' do
      it 'redirects to sign in with error' do
        wrong_token = MagicLinkToken.create!(
          user: user,
          purpose: 'password_reset',
          expires_at: 1.hour.from_now
        )

        get magic_link_dashboard_path(token: wrong_token.token)

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to eq('Invalid token purpose.')
      end
    end

    # Fifth test: valid token
    context 'with valid token' do
      let(:valid_token) { MagicLinkToken.create_dashboard_token(user) }

      it 'authenticates user and marks token as used' do
        expect(valid_token.used_at).to be_nil

        get magic_link_dashboard_path(token: valid_token.token)

        valid_token.reload
        expect(valid_token.used_at).not_to be_nil
        expect(flash[:notice]).to eq("Welcome back! You've been automatically signed in.")
      end

      context 'for school owner' do
        before { user.update!(role: 'school_owner') }

        it 'redirects to school owner dashboard' do
          get magic_link_dashboard_path(token: valid_token.token)
          expect(response).to redirect_to(school_owner_dashboard_index_path)
        end
      end

      context 'for admin user' do
        before { user.update!(role: 'admin') }

        it 'redirects to root path' do
          get magic_link_dashboard_path(token: valid_token.token)
          expect(response).to redirect_to(root_path)
        end
      end
    end

    # Security test: token timing attack prevention
    context 'security: timing attack prevention' do
      it 'takes similar time for valid and invalid tokens' do
        valid_token = MagicLinkToken.create_dashboard_token(user)

        # Measure time for valid token
        valid_start = Time.current
        get magic_link_dashboard_path(token: valid_token.token)
        valid_duration = Time.current - valid_start

        # Measure time for invalid token
        invalid_start = Time.current
        get magic_link_dashboard_path(token: 'invalid_token_abc123')
        invalid_duration = Time.current - invalid_start

        # Times should be reasonably similar (within 200ms to account for system variance)
        expect((valid_duration - invalid_duration).abs).to be < 0.2
      end
    end

    # Security test: one-time use enforcement
    context 'security: one-time use' do
      it 'prevents token reuse' do
        token = MagicLinkToken.create_dashboard_token(user)

        # First use should succeed
        get magic_link_dashboard_path(token: token.token)
        expect(response).to redirect_to(school_owner_dashboard_index_path)

        # Second use should fail
        get magic_link_dashboard_path(token: token.token)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to eq('Authentication token has expired or been used.')
      end
    end
  end
end
