require 'rails_helper'

RSpec.describe 'Schools', type: :request do
  describe 'GET /schools' do
    let!(:published_schools) { create_list(:school, 3) }
    let!(:draft_school) { create(:school, :draft) }
    
    it 'returns successful response' do
      get schools_path
      expect(response).to have_http_status(:ok)
    end
    
    it 'includes all published schools' do
      get schools_path
      published_schools.each do |school|
        expect(response.body).to include(school.name)
      end
    end
    
    it 'does not include draft schools' do
      get schools_path
      expect(response.body).not_to include(draft_school.name)
    end
    
    context 'with search parameter' do
      let!(:matching_school) { create(:school, name: 'Bangkok International School') }
      
      it 'returns filtered results as JSON' do
        get schools_path, params: { q: 'Bangkok' }, headers: { 'Accept' => 'application/json' }
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['schools']).to be_present
        expect(json_response['schools'].first['name']).to include('Bangkok')
      end
    end
  end
  
  describe 'GET /schools/:id' do
    let(:school) { create(:school, :with_media) }
    
    it 'returns successful response' do
      get school_path(id: school.id)
      expect(response).to have_http_status(:ok)
    end
    
    it 'displays school information' do
      get school_path(id: school.id)
      expect(response.body).to include(school.name)
      expect(response.body).to include(school.about) if school.about.present?
    end
    
    context 'when school does not exist' do
      it 'returns not found' do
        get school_path(id: 'non-existent')
        expect(response).to have_http_status(:not_found)
      end
    end
    
    context 'when school is draft' do
      let(:draft_school) { create(:school, :draft) }
      
      it 'returns not found for regular users' do
        get school_path(id: draft_school.id)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end