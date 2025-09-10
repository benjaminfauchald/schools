require 'rails_helper'

RSpec.describe SchoolFeeBand, type: :model do
  let(:school) { create(:school) }
  let(:fee_schedule) { create(:school_fee_schedule, school: school) }
  let(:fee_band) { create(:school_fee_band, school_fee_schedule: fee_schedule) }

  describe 'associations' do
    it { should belong_to(:school_fee_schedule) }
  end

  describe 'validations' do
    subject { build(:school_fee_band, school_fee_schedule: fee_schedule) }

    it { should validate_presence_of(:grade_from) }
    it { should validate_presence_of(:grade_to) }
    it { should validate_presence_of(:annual_tuition) }

    it { should validate_numericality_of(:grade_from).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(12) }
    it { should validate_numericality_of(:grade_to).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(12) }
    it { should validate_numericality_of(:annual_tuition).is_greater_than(0) }

    describe 'grade_to validation' do
      it 'requires grade_to to be >= grade_from' do
        band = build(:school_fee_band, school_fee_schedule: fee_schedule, grade_from: 5, grade_to: 3)
        expect(band).not_to be_valid
        expect(band.errors[:grade_to]).to include('must be greater than or equal to grade from')
      end

      it 'allows grade_to equal to grade_from' do
        band = build(:school_fee_band, school_fee_schedule: fee_schedule, grade_from: 5, grade_to: 5)
        expect(band).to be_valid
      end
    end

    describe 'overlapping bands validation' do
      it 'prevents overlapping grade ranges' do
        existing = create(:school_fee_band, school_fee_schedule: fee_schedule, grade_from: 1, grade_to: 5)
        
        overlapping = build(:school_fee_band, school_fee_schedule: fee_schedule, grade_from: 3, grade_to: 7)
        expect(overlapping).not_to be_valid
        expect(overlapping.errors[:base]).to include('Grade range overlaps with existing fee band')
      end

      it 'allows non-overlapping ranges' do
        existing = create(:school_fee_band, school_fee_schedule: fee_schedule, grade_from: 1, grade_to: 5)
        
        non_overlapping = build(:school_fee_band, school_fee_schedule: fee_schedule, grade_from: 6, grade_to: 8)
        expect(non_overlapping).to be_valid
      end

      it 'allows overlapping in different fee schedules' do
        other_schedule = create(:school_fee_schedule, school: school, academic_year: "2024-2025")
        existing = create(:school_fee_band, school_fee_schedule: fee_schedule, grade_from: 1, grade_to: 5)
        
        other_band = build(:school_fee_band, school_fee_schedule: other_schedule, grade_from: 1, grade_to: 5)
        expect(other_band).to be_valid
      end
    end

    describe 'uniqueness validation' do
      it 'validates uniqueness of grade_from scoped to schedule and grade_to' do
        existing = create(:school_fee_band, school_fee_schedule: fee_schedule, grade_from: 1, grade_to: 5)
        duplicate = build(:school_fee_band, school_fee_schedule: fee_schedule, grade_from: 1, grade_to: 5)
        
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:grade_from]).to include('overlaps with existing grade band')
      end
    end
  end

  describe 'scopes' do
    let!(:band1) { create(:school_fee_band, school_fee_schedule: fee_schedule, grade_from: 6, grade_to: 8) }
    let!(:band2) { create(:school_fee_band, school_fee_schedule: fee_schedule, grade_from: 1, grade_to: 5) }
    let!(:band3) { create(:school_fee_band, school_fee_schedule: fee_schedule, grade_from: 9, grade_to: 12) }

    describe '.ordered' do
      it 'orders by grade_from ascending' do
        expect(SchoolFeeBand.ordered).to eq([band2, band1, band3])
      end
    end

    describe '.covering_grade' do
      it 'returns bands covering specific grade' do
        expect(SchoolFeeBand.covering_grade(3)).to include(band2)
        expect(SchoolFeeBand.covering_grade(7)).to include(band1)
        expect(SchoolFeeBand.covering_grade(10)).to include(band3)
        expect(SchoolFeeBand.covering_grade(13)).to be_empty
      end
    end
  end

  describe 'instance methods' do
    describe '#grade_range_display' do
      it 'returns single grade for same from/to' do
        fee_band.grade_from = 5
        fee_band.grade_to = 5
        expect(fee_band.grade_range_display).to eq('Grade 5')
      end

      it 'returns range for different from/to' do
        fee_band.grade_from = 1
        fee_band.grade_to = 5
        expect(fee_band.grade_range_display).to eq('Grades 1-5')
      end
    end

    describe '#tuition_display' do
      it 'formats tuition with currency' do
        fee_band.annual_tuition = 50000
        fee_schedule.currency = 'THB'
        expect(fee_band.tuition_display).to eq('50,000 THB')
      end
    end

    describe '#covers_grade?' do
      it 'returns true for grades within range' do
        fee_band.grade_from = 1
        fee_band.grade_to = 5
        
        expect(fee_band.covers_grade?(1)).to be true
        expect(fee_band.covers_grade?(3)).to be true
        expect(fee_band.covers_grade?(5)).to be true
      end

      it 'returns false for grades outside range' do
        fee_band.grade_from = 1
        fee_band.grade_to = 5
        
        expect(fee_band.covers_grade?(0)).to be false
        expect(fee_band.covers_grade?(6)).to be false
      end
    end
  end

  describe 'private methods' do
    describe '#formatted_amount' do
      it 'formats numbers with commas' do
        expect(fee_band.send(:formatted_amount, 1000)).to eq('1,000')
        expect(fee_band.send(:formatted_amount, 1000000)).to eq('1,000,000')
        expect(fee_band.send(:formatted_amount, 100)).to eq('100')
      end
    end
  end

  describe 'factory' do
    it 'creates valid fee band' do
      band = build(:school_fee_band, school_fee_schedule: fee_schedule)
      expect(band).to be_valid
    end
  end
end