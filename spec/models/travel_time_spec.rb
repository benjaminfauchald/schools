require 'rails_helper'

RSpec.describe TravelTime, type: :model do
  let(:place) { create(:place) }
  let(:travel_time) { create(:travel_time, place: place) }

  describe 'associations' do
    it { should belong_to(:place) }
  end

  describe 'validations' do
    subject { build(:travel_time, place: place) }

    it { should validate_presence_of(:origin_hash) }
    it { should validate_presence_of(:mode) }
    it { should validate_presence_of(:computed_at) }
    it { should validate_uniqueness_of(:origin_hash).scoped_to(:place_id, :mode) }
    
    it 'validates mode inclusion' do
      valid_modes = %w[driving transit walking cycling]
      valid_modes.each do |mode|
        travel_time = build(:travel_time, place: place, mode: mode)
        expect(travel_time).to be_valid
      end

      travel_time = build(:travel_time, place: place, mode: 'flying')
      expect(travel_time).not_to be_valid
      expect(travel_time.errors[:mode]).to include('is not included in the list')
    end

    it 'validates minutes is positive when present' do
      travel_time = build(:travel_time, place: place, minutes: 30)
      expect(travel_time).to be_valid

      travel_time.minutes = 0
      expect(travel_time).not_to be_valid

      travel_time.minutes = -5
      expect(travel_time).not_to be_valid

      travel_time.minutes = nil
      expect(travel_time).to be_valid # allow_nil
    end
  end

  describe 'scopes' do
    let!(:driving_time) { create(:travel_time, place: place, mode: 'driving', origin_hash: 'hash1') }
    let!(:transit_time) { create(:travel_time, place: place, mode: 'transit', origin_hash: 'hash2') }
    let!(:recent_time) { create(:travel_time, place: place, computed_at: 1.hour.ago, origin_hash: 'hash3') }
    let!(:old_time) { create(:travel_time, place: place, computed_at: 2.days.ago, origin_hash: 'hash4') }
    let!(:successful_time) { create(:travel_time, place: place, minutes: 30, origin_hash: 'hash5') }
    let!(:failed_time) { create(:travel_time, place: place, minutes: nil, origin_hash: 'hash6') }

    describe '.by_mode' do
      it 'filters by transportation mode' do
        expect(TravelTime.by_mode('driving')).to include(driving_time)
        expect(TravelTime.by_mode('driving')).not_to include(transit_time)
      end
    end

    describe '.recent' do
      it 'returns recently computed times' do
        expect(TravelTime.recent(24)).to include(recent_time)
        expect(TravelTime.recent(24)).not_to include(old_time)
      end
    end

    describe '.stale' do
      it 'returns old computed times' do
        expect(TravelTime.stale(24)).to include(old_time)
        expect(TravelTime.stale(24)).not_to include(recent_time)
      end
    end

    describe '.successful' do
      it 'returns times with minutes calculated' do
        expect(TravelTime.successful).to include(successful_time)
        expect(TravelTime.successful).not_to include(failed_time)
      end
    end

    describe '.failed' do
      it 'returns times without minutes' do
        expect(TravelTime.failed).to include(failed_time)
        expect(TravelTime.failed).not_to include(successful_time)
      end
    end
  end

  describe 'instance methods' do
    describe '#stale?' do
      it 'returns true for old computations' do
        travel_time.computed_at = 2.days.ago
        expect(travel_time.stale?).to be true
      end

      it 'returns false for recent computations' do
        travel_time.computed_at = 1.hour.ago
        expect(travel_time.stale?).to be false
      end
    end

    describe '#successful?' do
      it 'returns true when minutes present' do
        travel_time.minutes = 30
        expect(travel_time.successful?).to be true
      end

      it 'returns false when minutes nil' do
        travel_time.minutes = nil
        expect(travel_time.successful?).to be false
      end
    end

    describe '#duration_display' do
      it 'formats hours and minutes' do
        travel_time.minutes = 90
        expect(travel_time.duration_display).to eq('1h 30m')
      end

      it 'formats hours only' do
        travel_time.minutes = 120
        expect(travel_time.duration_display).to eq('2h')
      end

      it 'formats minutes only' do
        travel_time.minutes = 45
        expect(travel_time.duration_display).to eq('45m')
      end

      it 'returns message when minutes nil' do
        travel_time.minutes = nil
        expect(travel_time.duration_display).to eq('Unable to calculate')
      end
    end

    describe '#mode_display' do
      it 'returns formatted mode with emoji' do
        travel_time.mode = 'driving'
        expect(travel_time.mode_display).to eq('🚗 Driving')

        travel_time.mode = 'transit'
        expect(travel_time.mode_display).to eq('🚌 Public Transit')

        travel_time.mode = 'walking'
        expect(travel_time.mode_display).to eq('🚶 Walking')

        travel_time.mode = 'cycling'
        expect(travel_time.mode_display).to eq('🚴 Cycling')
      end
    end

    describe '#full_display' do
      it 'combines duration and mode' do
        travel_time.minutes = 30
        travel_time.mode = 'driving'
        expect(travel_time.full_display).to eq('30m 🚗 driving')
      end
    end

    describe '#age_hours' do
      it 'calculates age in hours' do
        travel_time.computed_at = 5.hours.ago
        expect(travel_time.age_hours).to be_within(0.1).of(5.0)
      end
    end

    describe '#reasonable?' do
      it 'checks if travel time is reasonable for mode' do
        travel_time.mode = 'walking'
        travel_time.minutes = 60
        expect(travel_time.reasonable?).to be true

        travel_time.minutes = 150
        expect(travel_time.reasonable?).to be false

        travel_time.mode = 'driving'
        travel_time.minutes = 150
        expect(travel_time.reasonable?).to be true

        travel_time.minutes = 200
        expect(travel_time.reasonable?).to be false
      end

      it 'returns false when minutes nil' do
        travel_time.minutes = nil
        expect(travel_time.reasonable?).to be false
      end
    end

    describe '#distance_category' do
      it 'categorizes by time' do
        travel_time.minutes = 10
        expect(travel_time.distance_category).to eq('Very Close')

        travel_time.minutes = 25
        expect(travel_time.distance_category).to eq('Close')

        travel_time.minutes = 45
        expect(travel_time.distance_category).to eq('Moderate')

        travel_time.minutes = 75
        expect(travel_time.distance_category).to eq('Far')

        travel_time.minutes = 120
        expect(travel_time.distance_category).to eq('Very Far')
      end

      it 'returns Unknown when minutes nil' do
        travel_time.minutes = nil
        expect(travel_time.distance_category).to eq('Unknown')
      end
    end
  end

  describe 'class methods' do
    describe '.generate_origin_hash' do
      it 'generates hash from coordinates' do
        hash = TravelTime.generate_origin_hash(13.7563, 100.5018)
        expect(hash).to eq('13.756,100.502')
      end

      it 'accepts custom precision' do
        hash = TravelTime.generate_origin_hash(13.7563, 100.5018, precision: 1)
        expect(hash).to eq('13.8,100.5')
      end
    end

    describe '.find_or_compute' do
      it 'finds existing travel time' do
        existing = create(:travel_time, 
          place: place,
          origin_hash: '13.756,100.502',
          mode: 'driving',
          computed_at: 1.hour.ago
        )

        result = TravelTime.find_or_compute(place, 13.7563, 100.5018, mode: 'driving')
        expect(result).to eq(existing)
      end

      it 'creates new travel time when not found' do
        expect {
          TravelTime.find_or_compute(place, 13.7563, 100.5018, mode: 'transit')
        }.to change(TravelTime, :count).by(1)
      end

      it 'considers stale times for recomputation' do
        stale = create(:travel_time,
          place: place,
          origin_hash: '13.756,100.502',
          mode: 'driving',
          computed_at: 2.days.ago
        )

        result = TravelTime.find_or_compute(place, 13.7563, 100.5018, mode: 'driving')
        expect(result).to eq(stale)
        expect(result.stale?).to be true
      end
    end
  end

  describe 'factory' do
    it 'creates valid travel time' do
      travel_time = build(:travel_time, place: place)
      expect(travel_time).to be_valid
    end
  end
end