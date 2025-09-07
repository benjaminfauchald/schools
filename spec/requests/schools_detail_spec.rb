require 'rails_helper'

RSpec.describe 'Schools Detail Page', type: :request do
  let(:place) { create(:place, lat: 13.7563, lng: 100.5018) }
  let(:school) { create(:school, place: place) }
  let(:school_with_media) { create(:school, :with_media, place: place) }

  describe 'GET /schools/:id' do
    context 'with valid school ID' do
      it 'returns successful response' do
        get school_path(id: school.id)
        expect(response).to have_http_status(:ok)
      end

      it 'displays school information' do
        get school_path(id: school.id)
        expect(response.body).to include(school.name)
      end

      it 'includes proper meta tags' do
        get school_path(id: school.id)
        expect(response.body).to include('<meta name="description"')
        expect(response.body).to include('<meta name="keywords"')
      end

      it 'sets page title correctly' do
        get school_path(id: school.id)
        expect(response.body).to include("<title>#{school.name}")
      end
    end

    context 'with school slug' do
      let(:school_with_slug) { create(:school, slug: 'test-international-school') }

      it 'accepts slug instead of ID' do
        get school_path(id: school_with_slug.slug)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(school_with_slug.name)
      end

      it 'works with complex slugs' do
        complex_school = create(:school, slug: 'bangkok-international-school-of-excellence')
        get school_path(id: complex_school.slug)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with numeric ID' do
      it 'accepts numeric ID' do
        get school_path(id: school.id.to_s)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(school.name)
      end
    end

    context 'when school does not exist' do
      it 'returns 404 for non-existent ID' do
        get school_path(id: 999999)
        expect(response).to have_http_status(:not_found)
      end

      it 'returns 404 for non-existent slug' do
        get school_path(id: 'non-existent-school')
        expect(response).to have_http_status(:not_found)
      end

      it 'returns 404 for invalid format' do
        get school_path(id: 'invalid-id-format-123abc')
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with different school statuses' do
      let(:draft_school) { create(:school, :draft) }
      let(:suspended_school) { create(:school, status: 'suspended') }

      it 'shows draft schools' do
        get school_path(id: draft_school.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(draft_school.name)
      end

      it 'shows suspended schools' do
        get school_path(id: suspended_school.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(suspended_school.name)
      end
    end
  end

  describe 'data loading and N+1 prevention' do
    let!(:school_with_associations) do
      create(:school, :with_media).tap do |s|
        create(:school_fee_schedule, school: s)
        create(:school_grade_offering, school: s)
        create_list(:tagging, 3, taggable: s)
      end
    end

    it 'eager loads all required associations' do
      expect {
        get school_path(id: school_with_associations.id)
      }.to make_database_queries(count: 15..25) # Reasonable query count with eager loading
    end

    it 'includes place data' do
      get school_path(id: school_with_associations.id)
      expect(assigns(:school).place).to be_present
    end

    it 'includes current taggings and terms' do
      get school_path(id: school_with_associations.id)
      school = assigns(:school)
      expect(school.current_taggings).to be_loaded
      expect(school.current_terms).to be_loaded
    end

    it 'includes fee schedules' do
      get school_path(id: school_with_associations.id)
      school = assigns(:school)
      expect(school.school_fee_schedules).to be_loaded
    end

    it 'includes grade offerings' do
      get school_path(id: school_with_associations.id)
      school = assigns(:school)
      expect(school.school_grade_offering).to be_present
    end

    it 'includes media items through place' do
      get school_path(id: school_with_associations.id)
      school = assigns(:school)
      expect(school.place.media_items).to be_loaded
    end
  end

  describe 'SchoolDataMerger integration' do
    let(:school_with_place_data) do
      create(:school, place: create(:place,
        formatted_address: '123 Test Street',
        rating: 4.5,
        user_ratings_total: 100
      ))
    end

    it 'creates merged data instance' do
      get school_path(id: school_with_place_data.id)
      expect(assigns(:merged_data)).to be_present
    end

    it 'merges school and place data' do
      get school_path(id: school_with_place_data.id)
      merged_data = assigns(:merged_data)
      expect(merged_data.hero_data).to be_present
      expect(merged_data.contact_info).to be_present
      expect(merged_data.location_data).to be_present
    end
  end

  describe 'related point data' do
    let(:point) do
      create(:point,
        way: "SRID=4326;POINT(#{place.lng} #{place.lat})",
        name: 'Related Point'
      )
    end

    before do
      # Create a point near the school's location
      point
    end

    it 'finds related point data when available' do
      get school_path(id: school.id)
      expect(assigns(:related_point)).to be_present
    end

    it 'handles PostGIS errors gracefully' do
      allow_any_instance_of(SchoolsController).to receive(:find_related_point)
        .and_raise(ActiveRecord::StatementInvalid.new('PostGIS error'))

      get school_path(id: school.id)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'page metadata generation' do
    let(:school_with_metadata) do
      create(:school,
        name: 'Bangkok International Academy',
        district: 'Sukhumvit',
        province: 'Bangkok'
      )
    end

    it 'sets page title to school name' do
      get school_path(id: school_with_metadata.id)
      expect(assigns(:page_title)).to eq(school_with_metadata.name)
    end

    it 'generates page description' do
      get school_path(id: school_with_metadata.id)
      description = assigns(:page_description)
      expect(description).to include(school_with_metadata.name)
    end

    it 'generates SEO keywords' do
      get school_path(id: school_with_metadata.id)
      keywords = assigns(:page_keywords)
      expect(keywords).to include(school_with_metadata.name)
      expect(keywords).to include('school')
      expect(keywords).to include('education')
      expect(keywords).to include('bangkok')
    end

    it 'includes location in keywords' do
      get school_path(id: school_with_metadata.id)
      keywords = assigns(:page_keywords)
      expect(keywords).to include('Sukhumvit')
      expect(keywords).to include('Bangkok')
    end

    context 'with curriculum data' do
      let(:curriculum_vocab) { create(:vocabulary, code: 'curriculum') }
      let(:ib_curriculum) { create(:term, vocabulary: curriculum_vocab, label: 'IB Programme') }

      before do
        school_with_metadata.add_term(ib_curriculum)
      end

      it 'includes curriculum in keywords' do
        get school_path(id: school_with_metadata.id)
        keywords = assigns(:page_keywords)
        expect(keywords).to include('IB Programme')
      end
    end
  end

  describe 'response headers' do
    it 'sets appropriate content type' do
      get school_path(id: school.id)
      expect(response.content_type).to include('text/html')
    end

    it 'does not set cache headers for dynamic content' do
      get school_path(id: school.id)
      expect(response.headers['Cache-Control']).not_to include('public')
    end
  end

  describe 'error handling' do
    context 'when database error occurs' do
      before do
        allow(School).to receive(:includes).and_raise(ActiveRecord::ConnectionTimeoutError)
      end

      it 'handles database errors gracefully' do
        expect {
          get school_path(id: school.id)
        }.to raise_error(ActiveRecord::ConnectionTimeoutError)
      end
    end

    context 'with malformed parameters' do
      it 'handles special characters in slug' do
        expect {
          get school_path(id: 'test%20school')
        }.not_to raise_error
      end

      it 'handles SQL injection attempts' do
        expect {
          get school_path(id: "'; DROP TABLE schools; --")
        }.not_to raise_error
      end
    end
  end

  describe 'performance considerations' do
    let(:school_with_many_associations) do
      create(:school, :with_media).tap do |s|
        create_list(:school_fee_schedule, 5, school: s)
        create_list(:tagging, 10, taggable: s)
        create_list(:page, 3, school: s)
      end
    end

    it 'loads page efficiently even with many associations' do
      start_time = Time.current
      get school_path(id: school_with_many_associations.id)
      end_time = Time.current

      expect(response).to have_http_status(:ok)
      expect(end_time - start_time).to be < 1.second
    end

    it 'uses reasonable number of database queries' do
      queries = []
      ActiveSupport::Notifications.subscribe 'sql.active_record' do |_, _, _, _, payload|
        queries << payload[:sql] unless payload[:name] == 'SCHEMA'
      end

      get school_path(id: school_with_many_associations.id)

      # Should be efficient with eager loading
      expect(queries.count).to be < 30
    ensure
      ActiveSupport::Notifications.unsubscribe 'sql.active_record'
    end
  end

  describe 'ViewComponent integration' do
    it 'renders HeroComponent' do
      get school_path(id: school_with_media.id)
      expect(response.body).to include('hero-section')
    end

    it 'renders ContactFormComponent' do
      get school_path(id: school_with_media.id)
      expect(response.body).to include('contact-form')
    end

    it 'renders InteractiveMapComponent' do
      get school_path(id: school_with_media.id)
      expect(response.body).to include('interactive-map')
    end

    it 'renders PhotoGalleryComponent when media exists' do
      get school_path(id: school_with_media.id)
      expect(response.body).to include('photo-gallery')
    end
  end

  describe 'claim functionality integration' do
    context 'with unclaimed school' do
      it 'shows claim section for unclaimed school' do
        get school_path(id: school.id)
        expect(response.body).to include('Claim This School')
      end
    end

    context 'with claimed school' do
      before do
        create(:school_claim, :approved, school: school)
      end

      it 'does not show claim section for claimed school' do
        get school_path(id: school.id)
        expect(response.body).not_to include('Claim This School')
      end
    end
  end

  describe 'school pages integration' do
    let(:school_with_pages) do
      create(:school).tap do |s|
        create_list(:page, 3, school: s, status: 'published')
      end
    end

    it 'displays published pages section' do
      get school_path(id: school_with_pages.id)
      expect(response.body).to include('School Pages')
    end

    it 'shows page count' do
      get school_path(id: school_with_pages.id)
      expect(response.body).to include('3 pages available')
    end

    it 'does not show pages section when no published pages' do
      get school_path(id: school.id)
      expect(response.body).not_to include('School Pages')
    end
  end

  describe 'responsive meta tags' do
    it 'includes viewport meta tag' do
      get school_path(id: school.id)
      expect(response.body).to include('name="viewport"')
    end

    it 'includes mobile-optimized meta tags' do
      get school_path(id: school.id)
      expect(response.body).to include('width=device-width')
    end
  end

  describe 'accessibility features' do
    it 'includes proper heading structure' do
      get school_path(id: school.id)
      expect(response.body).to include('<h1')
    end

    it 'includes alt text for images' do
      get school_path(id: school_with_media.id)
      expect(response.body).to match(/alt=".+"/i)
    end

    it 'includes proper form labels' do
      get school_path(id: school.id)
      expect(response.body).to include('<label')
    end
  end
end
