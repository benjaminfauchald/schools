require 'rails_helper'

RSpec.describe School, type: :model do
  let(:school) { create(:school) }
  let(:school_with_place) { create(:school) }

  describe 'associations' do
    it 'belongs to place' do
      expect(school).to belong_to(:place).optional
    end

    it 'has many school_fee_schedules' do
      expect(school).to have_many(:school_fee_schedules).dependent(:destroy)
    end

    it 'has many school_claims' do
      expect(school).to have_many(:school_claims).dependent(:destroy)
    end

    it 'has many school_inquiries' do
      expect(school).to have_many(:school_inquiries).dependent(:destroy)
    end

    it 'has many pages' do
      expect(school).to have_many(:pages).dependent(:destroy)
    end

    it 'has many ai_conversations' do
      expect(school).to have_many(:ai_conversations).dependent(:destroy)
    end

    it 'has one school_grade_offering' do
      expect(school).to have_one(:school_grade_offering).dependent(:destroy)
    end

    it 'has many media_items through place' do
      expect(school).to have_many(:media_items).through(:place)
    end

    it 'has many taggings' do
      expect(school).to have_many(:taggings).dependent(:destroy)
    end

    it 'has many terms through taggings' do
      expect(school).to have_many(:terms).through(:taggings)
    end

    it 'has many current_taggings' do
      expect(school).to have_many(:current_taggings)
    end

    it 'has many current_terms through current_taggings' do
      expect(school).to have_many(:current_terms).through(:current_taggings)
    end
  end

  describe 'validations' do
    it 'validates presence of name' do
      school = build(:school, name: nil)
      expect(school).not_to be_valid
      expect(school.errors[:name]).to include("can't be blank")
    end

    it 'validates presence of slug' do
      school = build(:school, slug: nil)
      school.valid?
      # Slug should be auto-generated from name if blank
      expect(school.slug).to be_present
    end

    it 'validates uniqueness of slug' do
      create(:school, slug: 'test-school')
      school2 = build(:school, slug: 'test-school')
      expect(school2).not_to be_valid
      expect(school2.errors[:slug]).to include('has already been taken')
    end

    it 'validates email format when present' do
      school.email = 'invalid-email'
      expect(school).not_to be_valid
      expect(school.errors[:email]).to include('is invalid')
    end

    it 'allows blank email' do
      school.email = ''
      expect(school).to be_valid
    end

    it 'validates status inclusion' do
      expect { school.status = 'invalid_status' }.to raise_error(ArgumentError, "'invalid_status' is not a valid status")
    end

    it 'validates ownership inclusion when present' do
      expect { school.ownership = 'invalid_ownership' }.to raise_error(ArgumentError, "'invalid_ownership' is not a valid ownership")
    end

    it 'validates country_code inclusion when present' do
      school.country_code = 'XX'
      expect(school).not_to be_valid
      expect(school.errors[:country_code]).to include('is not included in the list')
    end
  end

  describe 'enums' do
    it 'defines status enum' do
      school.status = 'draft'
      expect(school.draft?).to be true

      school.status = 'published'
      expect(school.published?).to be true

      school.status = 'suspended'
      expect(school.suspended?).to be true
    end

    it 'defines ownership enum with prefix' do
      school.ownership = 'nonprofit'
      expect(school.ownership_nonprofit?).to be true

      school.ownership = 'private'
      expect(school.ownership_private?).to be true
    end
  end

  describe 'callbacks' do
    describe 'generate_slug' do
      it 'generates slug from name when name is present and slug is blank' do
        school = build(:school, name: 'Test School', slug: nil)
        school.valid?
        expect(school.slug).to eq('test-school')
      end

      it 'generates unique slug when duplicate exists' do
        create(:school, name: 'Test School', slug: 'test-school')
        school = build(:school, name: 'Test School', slug: nil)
        school.valid?
        expect(school.slug).to eq('test-school-1')
      end

      it 'does not generate slug when slug is already present' do
        school = build(:school, name: 'Test School', slug: 'custom-slug')
        school.valid?
        expect(school.slug).to eq('custom-slug')
      end
    end

    describe 'sync_geography_from_coordinates' do
      it 'updates geography when lat or lng changes' do
        expect(school).to receive(:update_geography!)
        school.update(lat: 13.7563, lng: 100.5018)
      end
    end

    describe 'sync_coordinates_from_place' do
      it 'syncs from place when place_id changes' do
        new_place = create(:place, lat: 13.8000, lng: 100.6000)
        expect(school).to receive(:sync_from_place!)
        school.update(place: new_place)
      end
    end
  end

  describe 'delegated methods' do
    let(:place) { create(:place, formatted_address: '123 Test St', rating: 4.5) }
    let(:school_with_place) { create(:school, place: place) }

    it 'delegates formatted_address to place' do
      expect(school_with_place.formatted_address).to eq('123 Test St')
    end

    it 'delegates rating to place' do
      expect(school_with_place.rating).to eq(4.5)
    end

    it 'handles nil place gracefully' do
      school.place = nil
      expect(school.formatted_address).to be_nil
    end
  end

  describe 'photo management' do
    let(:school_with_media) { create(:school, :with_media) }

    describe '#photos' do
      it 'returns photos through place media_items' do
        expect(school_with_media.photos).to be_present
      end

      it 'returns empty collection when no place' do
        school.place = nil
        expect(school.photos).to eq(MediaItem.none)
      end
    end

    describe 'photo visibility' do
      let(:photo) { { 'photo_reference' => 'test123' } }

      describe '#photo_visible?' do
        it 'returns true by default' do
          expect(school.photo_visible?(photo)).to be true
        end

        it 'respects visibility settings' do
          school.photo_visibility_settings = { 'test123' => false }
          expect(school.photo_visible?(photo)).to be false
        end
      end

      describe '#set_photo_visibility' do
        it 'updates photo visibility settings' do
          school.set_photo_visibility(photo, false)
          expect(school.photo_visibility_settings['test123']).to be false
        end
      end

      describe '#toggle_photo_visibility' do
        it 'toggles visibility and returns new state' do
          result = school.toggle_photo_visibility(photo)
          expect(result).to be false
          expect(school.photo_visibility_settings['test123']).to be false
        end
      end
    end
  end

  describe 'contact information display' do
    let(:place) { create(:place, formatted_phone_number: '+66 2 123 4567') }
    let(:school_with_place) { create(:school, place: place, phone: '02-987-6543') }

    describe '#display_phone' do
      it 'prefers school phone over place phone' do
        expect(school_with_place.display_phone).to eq('02-987-6543')
      end

      it 'falls back to place phone when school phone is blank' do
        school_with_place.phone = ''
        expect(school_with_place.display_phone).to eq('+66 2 123 4567')
      end
    end

    describe '#display_website' do
      it 'prefers school website_url over place website' do
        school.website_url = 'https://school.com'
        school.place = create(:place, website: 'https://place.com')
        expect(school.display_website).to eq('https://school.com')
      end

      it 'falls back to place website when school website_url is blank' do
        school.website_url = ''
        school.place = create(:place, website: 'https://place.com')
        expect(school.display_website).to eq('https://place.com')
      end
    end

    describe '#display_address' do
      it 'uses school address components when available' do
        school.address_line_1 = '123 School Street'
        school.district = 'Test District'
        school.province = 'Test Province'
        expected = '123 School Street, Test District, Test Province'
        expect(school.display_address).to eq(expected)
      end

      it 'falls back to place formatted_address' do
        school.address_line_1 = nil
        school.place = create(:place, formatted_address: '456 Place Street')
        expect(school.display_address).to eq('456 Place Street')
      end
    end
  end

  describe 'taxonomy methods' do
    let(:curriculum_vocab) { Vocabulary.find_or_create_by(code: 'curriculum') { |v| v.label = 'Curriculum'; v.description = 'Educational curriculum and programs' } }
    let(:facility_vocab) { Vocabulary.find_or_create_by(code: 'facility') { |v| v.label = 'Facilities'; v.description = 'Campus facilities and amenities' } }
    let(:curriculum_term) { create(:term, :ib_programme, vocabulary: curriculum_vocab) }
    let(:facility_term) { create(:term, :swimming_pool, vocabulary: facility_vocab) }

    before do
      school.add_term(curriculum_term)
      school.add_term(facility_term)
    end

    describe '#terms_by_context' do
      it 'returns terms filtered by vocabulary code' do
        curricula = school.terms_by_context('curriculum')
        expect(curricula).to include(curriculum_term)
        expect(curricula).not_to include(facility_term)
      end
    end

    describe '#curricula' do
      it 'returns curriculum terms' do
        expect(school.curricula).to include(curriculum_term)
      end
    end

    describe '#facilities' do
      it 'returns facility terms' do
        expect(school.facilities).to include(facility_term)
      end
    end

    describe '#add_term' do
      let(:new_term) { create(:term, vocabulary: curriculum_vocab, label: 'Cambridge IGCSE') }

      it 'creates tagging with term' do
        expect {
          school.add_term(new_term, notes: 'Test notes')
        }.to change { school.taggings.count }.by(1)

        tagging = school.taggings.find_by(term: new_term)
        expect(tagging.notes).to eq('Test notes')
        expect(tagging.context).to eq('curriculum')
      end
    end

    describe '#remove_term' do
      it 'destroys taggings for the term' do
        expect {
          school.remove_term(curriculum_term)
        }.to change { school.taggings.count }.by(-1)
      end
    end

    describe '#has_term?' do
      it 'returns true when school has the term' do
        expect(school.has_term?(curriculum_term)).to be true
      end

      it 'returns false when school does not have the term' do
        other_term = create(:term, vocabulary: curriculum_vocab)
        expect(school.has_term?(other_term)).to be false
      end

      it 'returns true when queried with term slug and context' do
        expect(school.has_term?(curriculum_term.slug, context: 'curriculum')).to be true
      end
    end
  end

  describe 'distance calculations' do
    describe '.calculate_haversine_distance' do
      it 'calculates distance between two points' do
        # Bangkok to Phuket (approximate)
        distance = School.calculate_haversine_distance(13.7563, 100.5018, 7.8804, 98.3923)
        expect(distance).to be_within(50).of(685) # ~685km
      end

      it 'returns zero for same coordinates' do
        distance = School.calculate_haversine_distance(13.7563, 100.5018, 13.7563, 100.5018)
        expect(distance).to eq(0.0)
      end
    end

    describe '.with_distance scope' do
      let!(:close_place) { create(:place, lat: 13.7563, lng: 100.5018) }
      let!(:far_place) { create(:place, lat: 14.0000, lng: 101.0000) }
      let!(:close_school) { create(:school, place: close_place, lat: 13.7563, lng: 100.5018, status: 'published') }
      let!(:far_school) { create(:school, place: far_place, lat: 14.0000, lng: 101.0000, status: 'published') }

      it 'returns schools within radius sorted by distance' do
        schools = School.with_distance(13.7563, 100.5018, 100)
        expect(schools.map(&:id)).to include(close_school.id, far_school.id)
        expect(schools.first.distance_km).to be <= schools.last.distance_km
      end

      it 'filters out schools beyond radius' do
        schools = School.with_distance(13.7563, 100.5018, 10)
        distances = schools.map(&:distance_km)
        expect(distances.all? { |d| d <= 10 }).to be true
      end

      it 'returns empty collection when no coordinates provided' do
        schools = School.with_distance(nil, nil, 50)
        expect(schools).to be_empty
      end
    end
  end

  describe 'claim methods' do
    describe '#claimed?' do
      it 'returns true when school has claims' do
        create(:school_claim, school: school)
        expect(school.claimed?).to be true
      end

      it 'returns false when school has no claims' do
        expect(school.claimed?).to be false
      end
    end

    describe '#approved_claims?' do
      it 'returns true when school has approved claims' do
        create(:school_claim, :approved, school: school)
        expect(school.approved_claims?).to be true
      end

      it 'returns false when school has no approved claims' do
        create(:school_claim, :pending, school: school)
        expect(school.approved_claims?).to be false
      end
    end

    describe '#active_claims?' do
      it 'returns true when school has active claims' do
        create(:school_claim, :approved, school: school)
        expect(school.active_claims?).to be true
      end
    end
  end

  describe 'YouTube video management' do
    describe '#has_youtube_channel?' do
      it 'returns true when youtube_url is present' do
        school.youtube_url = 'https://youtube.com/channel/test'
        expect(school.has_youtube_channel?).to be true
      end

      it 'returns false when youtube_url is blank' do
        school.youtube_url = ''
        expect(school.has_youtube_channel?).to be false
      end
    end

    describe '#video_visible?' do
      let(:video) { { video_id: 'abc123' } }

      it 'returns true by default' do
        expect(school.video_visible?(video)).to be true
      end

      it 'respects visibility settings' do
        school.video_visibility_settings = { 'abc123' => false }
        expect(school.video_visible?(video)).to be false
      end
    end
  end

  describe 'Facebook data methods' do
    describe '#has_facebook_data?' do
      it 'returns true when facebook_content is present' do
        school.update(facebook_content: { 'page_info' => { 'name' => 'Test School' } })
        expect(school.has_facebook_data?).to be true
      end

      it 'returns false when facebook_content is blank' do
        school.update(facebook_content: nil)
        expect(school.has_facebook_data?).to be false
      end
    end

    describe '#facebook_data_age_in_days' do
      it 'calculates age in days when facebook_last_fetched is present' do
        school.update(facebook_last_fetched: 5.days.ago)
        expect(school.facebook_data_age_in_days).to be_within(0.1).of(5.0)
      end

      it 'returns nil when facebook_last_fetched is nil' do
        school.update(facebook_last_fetched: nil)
        expect(school.facebook_data_age_in_days).to be_nil
      end
    end

    describe '#needs_facebook_refresh?' do
      it 'returns true when facebook_url present but never fetched' do
        school.update(facebook_url: 'https://facebook.com/testschool', facebook_last_fetched: nil)
        expect(school.needs_facebook_refresh?).to be true
      end

      it 'returns true when data is older than 30 days' do
        school.update(facebook_url: 'https://facebook.com/testschool', facebook_last_fetched: 31.days.ago)
        expect(school.needs_facebook_refresh?).to be true
      end

      it 'returns false when data is recent' do
        school.update(facebook_url: 'https://facebook.com/testschool', facebook_last_fetched: 1.day.ago)
        expect(school.needs_facebook_refresh?).to be false
      end
    end
  end

  describe 'scopes' do
    let!(:published_school) { create(:school, status: 'published') }
    let!(:draft_school) { create(:school, status: 'draft') }
    let!(:bangkok_school) { create(:school, district: 'Bangkok') }
    let!(:boarding_school) { create(:school, boarding: true) }

    describe '.published' do
      it 'returns only published schools' do
        schools = School.published
        expect(schools).to include(published_school)
        expect(schools).not_to include(draft_school)
      end
    end

    describe '.by_district' do
      it 'filters schools by district' do
        schools = School.by_district('Bangkok')
        expect(schools).to include(bangkok_school)
      end
    end

    describe '.with_boarding' do
      it 'returns schools with boarding' do
        schools = School.with_boarding
        expect(schools).to include(boarding_school)
      end
    end
  end

  describe 'address extraction from place' do
    let(:address_components) do
      [
        { 'types' => [ 'street_number' ], 'long_name' => '123' },
        { 'types' => [ 'route' ], 'long_name' => 'Test Street' },
        { 'types' => [ 'sublocality_level_1' ], 'long_name' => 'Test District' },
        { 'types' => [ 'administrative_area_level_1' ], 'long_name' => 'Test Province' },
        { 'types' => [ 'postal_code' ], 'long_name' => '12345' }
      ]
    end

    let(:place) { create(:place, address_components: address_components) }

    before do
      school.place = place
    end

    describe '#extract_street_from_place' do
      it 'combines street number and route' do
        street = school.send(:extract_street_from_place)
        expect(street).to eq('123 Test Street')
      end
    end

    describe '#extract_district_from_place' do
      it 'extracts sublocality_level_1' do
        district = school.send(:extract_district_from_place)
        expect(district).to eq('Test District')
      end
    end

    describe '#extract_province_from_place' do
      it 'extracts administrative_area_level_1' do
        province = school.send(:extract_province_from_place)
        expect(province).to eq('Test Province')
      end
    end

    describe '#extract_postcode_from_place' do
      it 'extracts postal_code' do
        postcode = school.send(:extract_postcode_from_place)
        expect(postcode).to eq('12345')
      end
    end
  end
end
