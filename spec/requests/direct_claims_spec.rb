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
      
      before { sign_in user }
      
      context 'when user already has approved claim for school' do
        let!(:approved_claim) { create(:school_claim, :approved, user: user, school: school) }
        
        it 'redirects with notice' do
          get new_direct_claim_path(school_id: school.id)
          expect(response).to redirect_to(school_owner_school_path(school))
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
      
      before { sign_in user }
      
      it 'returns validation error' do
        post create_direct_claim_path(school_id: school.id), 
             params: params_with_different_email,
             headers: { 'Accept' => 'application/json' }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
      end
    end
  end
end