require 'rails_helper'

RSpec.describe 'Magic Link Authentication', type: :request do
  # Critical missing test: Magic link authentication allows users to bypass normal login
  # with just a token. This is a MAJOR security feature that had ZERO test coverage.
  # If this breaks, attackers could gain unauthorized access or legitimate users
  # could be locked out of their accounts. This ONE test verifies the core security.

  it 'properly validates and authenticates users via magic link tokens' do
    # Create a user and valid token
    user = create(:user)
    valid_token = MagicLinkToken.create_dashboard_token(user)

    # TEST 1: Valid token authenticates user
    get "/en/auth/dashboard/#{valid_token.token}"
    expect(response).to have_http_status(:redirect)
    expect(flash[:notice]).to include("Welcome back")

    # Verify token was marked as used (one-time use)
    valid_token.reload
    expect(valid_token.used_at).to be_present

    # Sign out for next test
    delete "/en/users/sign_out"

    # TEST 2: Used token cannot be reused (prevents replay attacks)
    get "/en/auth/dashboard/#{valid_token.token}"
    expect(response).to redirect_to(new_user_session_path)
    expect(flash[:alert]).to include("expired or been used")

    # TEST 3: Expired tokens are rejected
    expired_token = MagicLinkToken.create_dashboard_token(user)
    expired_token.update!(expires_at: 1.hour.ago)

    get "/en/auth/dashboard/#{expired_token.token}"
    expect(response).to redirect_to(new_user_session_path)
    expect(flash[:alert]).to include("expired")

    # TEST 4: Invalid tokens are rejected
    get "/en/auth/dashboard/invalid-fake-token-xyz"
    expect(response).to redirect_to(new_user_session_path)
    expect(flash[:alert]).to include("Invalid")

    # TEST 5: Wrong purpose tokens are rejected
    wrong_token = MagicLinkToken.create!(
      user: user,
      purpose: "password_reset",  # Wrong purpose
      expires_at: 1.hour.from_now
    )

    get "/en/auth/dashboard/#{wrong_token.token}"
    expect(response).to redirect_to(new_user_session_path)
    expect(flash[:alert]).to include("Invalid token purpose")

    # TEST 6: School owners get redirected to their dashboard
    school_owner = create(:user)
    school_owner.update!(role: 'school_owner')
    owner_token = MagicLinkToken.create_dashboard_token(school_owner)

    get "/en/auth/dashboard/#{owner_token.token}"
    expect(response).to redirect_to(school_owner_dashboard_index_path)
  end
end
