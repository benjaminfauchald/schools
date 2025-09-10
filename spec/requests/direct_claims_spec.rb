require 'rails_helper'

RSpec.describe 'DirectClaims', type: :request do
  let(:school) { create(:school) }

  describe 'GET /schools/:school_id/claim' do
    it 'returns successful response' do
      get new_direct_claim_path(school_id: school.id)
      expect(response).to have_http_status(:ok)
    end

    it 'displays claim form' do
      get new_direct_claim_path(school_id: school.id)
      expect(response.body).to include('Claim Your School')
      expect(response.body).to include(school.name)
    end

    context 'when user is already signed in' do
      let(:user) { create(:user) }

      before { sign_in user, scope: :user }

      context 'when user already has approved claim for school' do
        let!(:approved_claim) { create(:school_claim, :approved, user: user, school: school) }

        it 'redirects with notice' do
          get new_direct_claim_path(school_id: school.id)
          expect(response).to redirect_to(school_owner_school_path(id: school.id))
          expect(flash[:notice]).to include('already manage')
        end
      end

      context 'when user has pending claim for school' do
        let!(:pending_claim) { create(:school_claim, user: user, school: school) }

        it 'redirects to claims page' do
          get new_direct_claim_path(school_id: school.id)
          expect(response).to redirect_to(school_owner_claims_path)
          expect(flash[:notice]).to include('pending claim')
        end
      end
    end
  end

  describe 'POST /schools/:school_id/claim' do
    let(:valid_params) do
      {
        direct_claim: {
          email: 'test@example.com',
          evidence_url: 'https://example.com/evidence',
          notes: 'I am the school owner'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a school claim' do
        expect {
          post create_direct_claim_path(school_id: school.id), params: valid_params
        }.to change(SchoolClaim, :count).by(1)
      end

      it 'creates a new user if email does not exist' do
        expect {
          post create_direct_claim_path(school_id: school.id), params: valid_params
        }.to change(User, :count).by(1)
      end

      it 'returns JSON success response' do
        post create_direct_claim_path(school_id: school.id),
             params: valid_params,
             headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['title']).to eq('Claim Submitted Successfully!')
        expect(json_response['school_name']).to eq(school.name)
      end

      it 'redirects to success page for HTML requests' do
        post create_direct_claim_path(school_id: school.id), params: valid_params
        expect(response).to redirect_to(direct_claim_success_path)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        { direct_claim: { email: '' } }
      end

      it 'does not create a school claim' do
        expect {
          post create_direct_claim_path(school_id: school.id), params: invalid_params
        }.not_to change(SchoolClaim, :count)
      end

      it 'returns validation errors for JSON requests' do
        post create_direct_claim_path(school_id: school.id),
             params: invalid_params,
             headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['errors']).to be_present
      end

      it 're-renders form for HTML requests' do
        post create_direct_claim_path(school_id: school.id), params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Claim Your School')
      end
    end

    context 'when user is signed in with different email' do
      let(:user) { create(:user, email: 'signed_in@example.com') }
      let(:params_with_different_email) do
        {
          direct_claim: {
            email: 'different@example.com',
            evidence_url: 'https://example.com',
            notes: 'Test'
          }
        }
      end

      before { sign_in user, scope: :user }

      it 'returns validation error' do
        post create_direct_claim_path(school_id: school.id),
             params: params_with_different_email,
             headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
      end
    end

    # CRITICAL TEST: Prevents duplicate claims with same email for same school
    # This test fills a security gap - without this check, users could spam multiple
    # claims for the same school, potentially creating duplicate accounts or claims.
    context 'duplicate claim prevention for same email and school' do
      let(:claim_params) do
        {
          direct_claim: {
            email: 'school.owner@example.com',
            evidence_url: 'https://school-website.com/about/owner',
            notes: 'I am the principal of this school'
          }
        }
      end

      it 'prevents duplicate claims from same email for same school' do
        # First claim should succeed
        expect {
          post create_direct_claim_path(school_id: school.id),
               params: claim_params,
               headers: { 'Accept' => 'application/json' }
        }.to change(SchoolClaim, :count).by(1)

        expect(response).to have_http_status(:ok)
        first_response = JSON.parse(response.body)
        expect(first_response['success']).to be true

        # Store first claim for comparison
        first_claim = SchoolClaim.last

        # Second claim with same email for same school should fail
        expect {
          post create_direct_claim_path(school_id: school.id),
               params: claim_params,
               headers: { 'Accept' => 'application/json' }
        }.not_to change(SchoolClaim, :count)

        # Should not create a duplicate user
        expect(User.where(email: 'school.owner@example.com').count).to eq(1)

        # Response should indicate claim already exists
        second_response = JSON.parse(response.body)
        expect(second_response['success']).to be_falsey

        # Verify only one claim exists for this email/school combination
        claims = SchoolClaim.joins(:user).where(
          school: school,
          users: { email: 'school.owner@example.com' }
        )
        expect(claims.count).to eq(1)
        expect(claims.first).to eq(first_claim)
      end

      it 'allows same email to claim different schools' do
        other_school = create(:school, name: 'Different School')

        # First claim for school 1
        post create_direct_claim_path(school_id: school.id),
             params: claim_params,
             headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:ok)

        # Same email can claim a different school
        expect {
          post create_direct_claim_path(school_id: other_school.id),
               params: claim_params,
               headers: { 'Accept' => 'application/json' }
        }.to change(SchoolClaim, :count).by(1)

        expect(response).to have_http_status(:ok)

        # Verify both claims exist but for different schools
        user = User.find_by(email: 'school.owner@example.com')
        claims = user.school_claims
        expect(claims.count).to eq(2)
        expect(claims.map(&:school_id)).to match_array([ school.id, other_school.id ])
      end

      it 'prevents rapid successive claim attempts for same school' do
        # Simulate rapid fire submissions (potential bot/spam attack)
        results = []

        5.times do
          post create_direct_claim_path(school_id: school.id),
               params: claim_params,
               headers: { 'Accept' => 'application/json' }
          results << { status: response.status, body: JSON.parse(response.body) }
        end

        # Only first request should succeed
        expect(results.first[:status]).to eq(200)
        expect(results.first[:body]['success']).to be true

        # All subsequent requests should fail
        results[1..].each do |result|
          expect(result[:body]['success']).to be_falsey
        end

        # Only one claim should be created
        expect(SchoolClaim.joins(:user).where(
          school: school,
          users: { email: 'school.owner@example.com' }
        ).count).to eq(1)

        # Only one user account should be created
        expect(User.where(email: 'school.owner@example.com').count).to eq(1)
      end

      it 'handles case-insensitive email matching' do
        # Submit with lowercase email
        post create_direct_claim_path(school_id: school.id),
             params: {
               direct_claim: {
                 email: 'owner@example.com',
                 evidence_url: 'https://example.com',
                 notes: 'First submission'
               }
             },
             headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:ok)

        # Try to submit with uppercase version of same email
        expect {
          post create_direct_claim_path(school_id: school.id),
               params: {
                 direct_claim: {
                   email: 'OWNER@EXAMPLE.COM',
                   evidence_url: 'https://example.com',
                   notes: 'Duplicate attempt'
                 }
               },
               headers: { 'Accept' => 'application/json' }
        }.not_to change(SchoolClaim, :count)

        # Should not create duplicate users with different case
        expect(User.where('LOWER(email) = ?', 'owner@example.com').count).to eq(1)
      end
    end
  end
end
