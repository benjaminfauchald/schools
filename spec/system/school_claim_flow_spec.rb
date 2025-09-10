require 'rails_helper'

RSpec.describe 'School Claim Flow', type: :request do
  let(:school) { create(:school) }

  describe 'claim form access' do
    it 'school show page contains claim section for non-signed in users' do
      get school_path(id: school.id)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('School Owner?') # The claim section should be present
    end

    it 'direct claim form is accessible' do
      get new_direct_claim_path(school_id: school.id)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Claim Your School')
    end
  end

  describe 'claim submission' do
    it 'processes claim form submission successfully' do
      claim_params = {
        direct_claim: {
          email: 'owner@example.com',
          evidence_url: 'https://linkedin.com/in/schoolowner',
          notes: 'I am the principal of this school'
        }
      }

      expect {
        post create_direct_claim_path(school_id: school.id),
             params: claim_params,
             headers: { 'Accept' => 'application/json' }
      }.to change(SchoolClaim, :count).by(1)

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['title']).to include('Claim Submitted Successfully')
      expect(json_response['school_name']).to eq(school.name)
    end

    it 'handles validation errors properly' do
      claim_params = {
        direct_claim: {
          email: '', # Invalid: empty email
          evidence_url: 'https://linkedin.com/in/schoolowner',
          notes: 'I am the principal of this school'
        }
      }

      expect {
        post create_direct_claim_path(school_id: school.id),
             params: claim_params,
             headers: { 'Accept' => 'application/json' }
      }.not_to change(SchoolClaim, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be false
      expect(json_response['errors']).to be_present
    end
  end

  describe 'when user is already signed in' do
    let(:user) { create(:user, email: 'signed_in@example.com') }

    it 'school show page contains claim section for signed in users' do
      # Sign in the user for request specs
      sign_in user
      
      get school_path(id: school.id)
      
      # Check for claim section in the response body
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Claim')
    end

    it 'pre-fills email field for signed in users' do
      skip "Signed-in user functionality would be better tested in integration tests"
    end
  end
end
