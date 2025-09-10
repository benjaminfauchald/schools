require 'rails_helper'

# This test protects the critical Direct School Claim workflow that allows school owners
# to claim their schools with automatic account creation. This is a key business feature
# that enables self-service onboarding of school administrators. The test ensures that:
# 1. New users can claim schools and get accounts created automatically
# 2. Existing users can claim additional schools
# 3. Claims are properly tracked and prevent duplicates
# 4. The complete workflow from claim to success page works correctly

RSpec.describe 'Direct School Claim Complete Workflow', type: :request do
  describe 'School owner claiming process with automatic account creation' do
    let(:school) { create(:school, name: 'Bangkok International Academy') }
    let(:second_school) { create(:school, name: 'Thailand Tech School') }

    it 'completes the entire claim workflow for new and existing users with all side effects' do
      # PART 1: New user claims their first school (auto-creates account)

      # Visit the claim page
      get new_direct_claim_path(school_id: school.id)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Claim Your School')
      expect(response.body).to include(school.name)

      # Submit claim as a new user (no account exists yet)
      new_user_email = 'principal@bangkokacademy.com'

      expect {
        post create_direct_claim_path(school_id: school.id), params: {
          direct_claim: {
            email: new_user_email,
            evidence_url: 'https://bangkokacademy.com/staff',
            notes: 'I am the principal, you can verify on our website'
          }
        }
      }.to change { User.count }.by(1)
       .and change { SchoolClaim.count }.by(1)

      # Verify redirect to success page
      expect(response).to redirect_to(direct_claim_success_path)
      follow_redirect!

      # Verify success page shows correct information
      expect(response.body).to include('Claim Submitted Successfully')
      expect(response.body).to include(school.name)
      expect(response.body).to include('check your email to verify your account')

      # Verify user was created with correct attributes
      new_user = User.find_by(email: new_user_email)
      expect(new_user).to be_present
      expect(new_user.role).to eq('school_owner')
      expect(new_user.confirmed_at).to be_nil # Not confirmed yet

      # Verify claim was created with correct attributes
      claim = SchoolClaim.find_by(user: new_user, school: school)
      expect(claim).to be_present
      expect(claim.status).to eq('pending')
      expect(claim.evidence_url).to eq('https://bangkokacademy.com/staff')

      # PART 2: Same email tries to claim the same school again (should be prevented)

      get new_direct_claim_path(school_id: school.id)

      post create_direct_claim_path(school_id: school.id), params: {
        direct_claim: {
          email: new_user_email,
          evidence_url: 'https://bangkokacademy.com/about',
          notes: 'Attempting duplicate claim'
        }
      }

      # Should not create duplicate user or claim
      expect(User.where(email: new_user_email).count).to eq(1)
      expect(SchoolClaim.where(user: new_user, school: school).count).to eq(1)

      # Should show error message in response body
      expect(response).to have_http_status(:unprocessable_entity)

      # PART 3: Same user claims a different school (should work)

      expect {
        post create_direct_claim_path(school_id: second_school.id), params: {
          direct_claim: {
            email: new_user_email,
            evidence_url: 'https://thailandtech.com/leadership',
            notes: 'I also manage this campus'
          }
        }
      }.to change { SchoolClaim.count }.by(1)
       .and change { User.count }.by(0) # No new user created

      expect(response).to redirect_to(direct_claim_success_path)

      # Verify second claim was created
      second_claim = SchoolClaim.find_by(user: new_user, school: second_school)
      expect(second_claim).to be_present
      expect(second_claim.status).to eq('pending')

      # PART 4: Existing confirmed user claims a school

      existing_user = create(:user,
        email: 'admin@existingschool.com',
        role: 'school_owner',
        confirmed_at: 1.day.ago
      )

      sign_in existing_user

      third_school = create(:school, name: 'Existing User New School')

      expect {
        post create_direct_claim_path(school_id: third_school.id), params: {
          direct_claim: {
            email: existing_user.email,
            evidence_url: 'https://existingschool.com/team',
            notes: 'Adding another school to my portfolio'
          }
        }
      }.to change { SchoolClaim.count }.by(1)
       .and change { User.count }.by(0)

      expect(response).to redirect_to(direct_claim_success_path)
      follow_redirect!

      # Message should be different for existing confirmed users
      expect(response.body).to include('Additional claim submitted')
      expect(response.body).not_to include('check your email to verify')

      # PART 5: User with approved claim tries to claim same school again

      create(:school_claim,
        user: existing_user,
        school: school,
        status: 'approved'
      )

      get new_direct_claim_path(school_id: school.id)

      # Should redirect immediately without showing form
      expect(response).to redirect_to(school_owner_school_path(id: school.id))
      expect(flash[:notice]).to include('already manage')

      # PART 6: User with rejected claim can re-claim with new evidence

      rejected_school = create(:school, name: 'Previously Rejected School')
      rejected_claim = create(:school_claim,
        user: existing_user,
        school: rejected_school,
        status: 'rejected',
        admin_notes: 'Insufficient evidence provided'
      )

      old_updated_at = rejected_claim.updated_at

      expect {
        post create_direct_claim_path(school_id: rejected_school.id), params: {
          direct_claim: {
            email: existing_user.email,
            evidence_url: 'https://rejected-school.com/legal-documents',
            notes: 'Providing additional legal documentation'
          }
        }
      }.to change { SchoolClaim.count }.by(0) # Reuses existing claim

      expect(response).to redirect_to(direct_claim_success_path)

      # Verify claim was updated, not recreated
      rejected_claim.reload
      expect(rejected_claim.status).to eq('pending')
      expect(rejected_claim.evidence_url).to eq('https://rejected-school.com/legal-documents')
      expect(rejected_claim.admin_notes).to be_nil # Previous rejection notes cleared
      expect(rejected_claim.updated_at).to be > old_updated_at

      # PART 7: Verify validation requirements

      sign_out existing_user

      # Missing email
      post create_direct_claim_path(school_id: school.id), params: {
        direct_claim: {
          email: '',
          evidence_url: 'https://example.com',
          notes: 'Test'
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)

      # Invalid email format
      post create_direct_claim_path(school_id: school.id), params: {
        direct_claim: {
          email: 'not-an-email',
          evidence_url: 'https://example.com',
          notes: 'Test'
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)

      # PART 8: Signed-in user trying to claim with different email

      sign_in existing_user

      another_unclaimed_school = create(:school, name: 'Unclaimed School For Test')

      post create_direct_claim_path(school_id: another_unclaimed_school.id), params: {
        direct_claim: {
          email: 'different@email.com', # Not matching signed-in user
          evidence_url: 'https://example.com',
          notes: 'Trying different email'
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)

      # PART 9: JSON API responses work correctly

      sign_out existing_user

      post create_direct_claim_path(school_id: school.id),
           params: {
             direct_claim: {
               email: 'api-user@school.com',
               evidence_url: 'https://api-school.com/verify',
               notes: 'API claim test'
             }
           },
           headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['school_name']).to eq(school.name)
      expect(json['created_user']).to be true
      expect(json['claim_id']).to be_present
      expect(json['message']).to include('check your email')

      # PART 10: Non-existent school handling

      get new_direct_claim_path(school_id: 999999)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include('not found')
    end

    it 'handles session expiry on success page gracefully' do
      # Try to access success page without going through claim flow
      get direct_claim_success_path

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include('expired')
    end
  end
end
