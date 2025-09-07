require 'rails_helper'

RSpec.describe 'Basic Test', type: :request do
  before do
    # Clean setup without database cleaner interference
    School.delete_all
    Place.delete_all
  end

  it 'can create a school with place and test basic route' do
    place = Place.create!(
      place_id: 'test_place_123',
      name: 'Test Place',
      lat: 13.7563,
      lng: 100.5018,
      formatted_address: 'Test Address'
    )

    school = School.create!(
      name: 'Test School',
      place: place,
      status: 'published',
      lat: 13.7563,
      lng: 100.5018
    )

    # Mock location methods
    allow_any_instance_of(ApplicationController).to receive(:puppeteer_request?).and_return(true)
    allow_any_instance_of(SchoolsController).to receive(:get_home_location_from_client).and_return({ lat: 13.7563, lng: 100.5018 })

    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Schools')
  end
end
