require 'rails_helper'

RSpec.describe Point, type: :model do
  let(:point) { create(:point) }

  describe 'associations' do
    it { should have_many(:places).dependent(:destroy) }
    it { should have_one(:primary_place).class_name('Place') }
  end

  describe 'validations' do
    subject { build(:point) }

    it { should validate_presence_of(:osm_id) }
    it { should validate_uniqueness_of(:osm_id) }
    it { should validate_presence_of(:lat) }
    it { should validate_presence_of(:lon) }
    it { should validate_numericality_of(:lat) }
    it { should validate_numericality_of(:lon) }
  end

  describe 'scopes' do
    let!(:school_point) { create(:point, amenity: 'school', name: 'Test School') }
    let!(:restaurant_point) { create(:point, amenity: 'restaurant', name: 'Test Restaurant') }
    let!(:unnamed_point) { create(:point, name: nil, amenity: 'school') }
    let!(:no_amenity_point) { create(:point, amenity: nil, name: 'Test Place') }

    describe '.schools' do
      it 'returns only school points' do
        expect(Point.schools).to include(school_point, unnamed_point)
        expect(Point.schools).not_to include(restaurant_point, no_amenity_point)
      end
    end

    describe '.with_names' do
      it 'returns only named points' do
        expect(Point.with_names).to include(school_point, restaurant_point, no_amenity_point)
        expect(Point.with_names).not_to include(unnamed_point)
      end
    end

    describe '.with_amenity' do
      it 'returns points with amenity set' do
        expect(Point.with_amenity).to include(school_point, restaurant_point, unnamed_point)
        expect(Point.with_amenity).not_to include(no_amenity_point)
      end
    end
  end

  describe 'instance methods' do
    describe '#coordinates' do
      it 'returns lat and lon as array' do
        point = build(:point, lat: 13.7563, lon: 100.5018)
        expect(point.coordinates).to eq([13.7563, 100.5018])
      end
    end

    describe '#named?' do
      it 'returns true when name is present' do
        point.name = 'Test Point'
        expect(point.named?).to be true
      end

      it 'returns false when name is blank' do
        point.name = ''
        expect(point.named?).to be false
      end

      it 'returns false when name is nil' do
        point.name = nil
        expect(point.named?).to be false
      end
    end

    describe '#has_amenity?' do
      it 'returns true when amenity is present' do
        point.amenity = 'school'
        expect(point.has_amenity?).to be true
      end

      it 'returns false when amenity is blank' do
        point.amenity = ''
        expect(point.has_amenity?).to be false
      end

      it 'returns false when amenity is nil' do
        point.amenity = nil
        expect(point.has_amenity?).to be false
      end
    end

    describe '#google_place_data' do
      it 'returns primary_place' do
        place = create(:place, point: point)
        expect(point.google_place_data).to eq(place)
      end

      it 'returns nil when no places' do
        expect(point.google_place_data).to be_nil
      end

      it 'returns first place when multiple exist' do
        place1 = create(:place, point: point, created_at: 1.day.ago)
        place2 = create(:place, point: point, created_at: 1.hour.ago)
        expect(point.google_place_data).to eq(place1)
      end
    end
  end

  describe 'OSM data fields' do
    it 'stores address components' do
      point = create(:point,
        addr_housenumber: '123',
        addr_street: 'Sukhumvit Road',
        addr_city: 'Bangkok',
        addr_postcode: '10110'
      )

      expect(point.addr_housenumber).to eq('123')
      expect(point.addr_street).to eq('Sukhumvit Road')
      expect(point.addr_city).to eq('Bangkok')
      expect(point.addr_postcode).to eq('10110')
    end

    it 'stores multilingual names' do
      point = create(:point,
        name: 'International School',
        name_en: 'International School',
        name_th: 'โรงเรียนนานาชาติ',
        alt_name: 'IS Bangkok'
      )

      expect(point.name_en).to eq('International School')
      expect(point.name_th).to eq('โรงเรียนนานาชาติ')
      expect(point.alt_name).to eq('IS Bangkok')
    end
  end

  describe 'factory' do
    it 'creates valid point' do
      point = build(:point)
      expect(point).to be_valid
    end

    it 'creates unique osm_ids' do
      point1 = create(:point)
      point2 = create(:point)
      expect(point1.osm_id).not_to eq(point2.osm_id)
    end
  end
end