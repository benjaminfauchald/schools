require 'rails_helper'

RSpec.describe School, type: :model do
  let(:school) { build(:school) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(school).to be_valid
    end

    it 'validates presence of name' do
      school.name = nil
      expect(school).not_to be_valid
      expect(school.errors[:name]).to include("can't be blank")
    end

    it 'validates presence of slug' do
      school.slug = nil
      school.valid?
      expect(school.slug).to be_present # Auto-generated from name
    end

    it 'validates uniqueness of slug' do
      create(:school, slug: 'test-school')
      school.slug = 'test-school'
      expect(school).not_to be_valid
      expect(school.errors[:slug]).to include('has already been taken')
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
      expect {
        school.status = 'invalid_status'
      }.to raise_error(ArgumentError, "'invalid_status' is not a valid status")
    end

    it 'validates ownership inclusion when present' do
      expect {
        school.ownership = 'invalid_ownership'
      }.to raise_error(ArgumentError, "'invalid_ownership' is not a valid ownership")
    end

    it 'validates country_code inclusion when present' do
      school.country_code = 'XX'
      expect(school).not_to be_valid
      expect(school.errors[:country_code]).to include('is not included in the list')
    end
  end

  describe 'enums' do
    it 'defines status enum' do
      school = create(:school, status: 'draft')
      expect(school.draft?).to be true

      school.status = 'published'
      expect(school.published?).to be true

      school.status = 'suspended'
      expect(school.suspended?).to be true
    end

    it 'defines ownership enum with prefix' do
      school = create(:school, ownership: 'nonprofit')
      expect(school.ownership_nonprofit?).to be true

      school.ownership = 'private'
      expect(school.ownership_private?).to be true
    end
  end

  describe 'slug generation' do
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

  describe 'scopes' do
    let!(:published_school) { create(:school, status: 'published') }
    let!(:draft_school) { create(:school, status: 'draft') }
    let!(:bangkok_school) { create(:school, district: 'Bangkok') }
    let!(:boarding_school) { create(:school, boarding: true) }

    it 'filters published schools' do
      schools = School.published
      expect(schools).to include(published_school)
      expect(schools).not_to include(draft_school)
    end

    it 'filters schools by district' do
      schools = School.by_district('Bangkok')
      expect(schools).to include(bangkok_school)
    end

    it 'filters schools with boarding' do
      schools = School.with_boarding
      expect(schools).to include(boarding_school)
    end
  end

  describe 'claim methods' do
    it 'returns false when school has no claims' do
      expect(school.claimed?).to be false
    end
  end
end
