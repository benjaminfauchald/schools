require 'rails_helper'

RSpec.describe 'Simple Routes', type: :request do
  # Create minimal test data
  let!(:school) { create(:school, status: 'published') }

  # Mock location data to avoid external API calls
  let(:test_coordinates) { { lat: 13.7563, lng: 100.5018 } }

  before do
    # Mock Puppeteer detection to bypass onboarding redirects
    allow_any_instance_of(ApplicationController).to receive(:puppeteer_request?).and_return(true)

    # Mock location methods in SchoolsController specifically
    allow_any_instance_of(SchoolsController).to receive(:get_home_location_from_client).and_return(test_coordinates)
  end

  it 'returns 200 for root path' do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Schools')
  end

  it 'returns 200 for settings' do
    get '/settings'
    expect(response).to have_http_status(:ok)
  end

  it 'returns 200 for terms of service' do
    get terms_of_service_path
    expect(response).to have_http_status(:ok)
  end
end
