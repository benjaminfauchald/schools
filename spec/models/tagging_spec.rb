require 'rails_helper'

RSpec.describe Tagging, type: :model do
  let(:school) { create(:school) }
  let(:vocabulary) { create(:vocabulary, code: 'curriculum') }
  let(:term) { create(:term, vocabulary: vocabulary, label: 'IB Programme') }
  let(:tagging) { create(:tagging, taggable: school, term: term, context: 'curriculum') }

  describe 'associations' do
    it { should belong_to(:taggable) }
    it { should belong_to(:term) }
  end

  describe 'validations' do
    subject { build(:tagging, taggable: school, term: term, context: 'curriculum') }

    it { should validate_presence_of(:taggable_type) }
    it { should validate_presence_of(:taggable_id) }
    it { should validate_presence_of(:term_id) }
    it { should validate_presence_of(:context) }
    
    it 'validates uniqueness of term_id scoped to taggable and context' do
      existing = create(:tagging, taggable: school, term: term, context: 'curriculum')
      duplicate = build(:tagging, taggable: school, term: term, context: 'curriculum')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:term_id]).to include('already tagged with this term in this context')
    end

    describe 'context validation' do
      it 'requires context to match vocabulary code' do
        tagging = build(:tagging, taggable: school, term: term, context: 'wrong')
        expect(tagging).not_to be_valid
        expect(tagging.errors[:context]).to include("must match vocabulary code 'curriculum'")
      end

      it 'accepts matching context' do
        tagging = build(:tagging, taggable: school, term: term, context: 'curriculum')
        expect(tagging).to be_valid
      end
    end

  end

  describe 'scopes' do
    let!(:curriculum_tagging) { create(:tagging, taggable: school, term: term, context: 'curriculum') }
    let!(:facility_vocab) { create(:vocabulary, code: 'facility') }
    let!(:facility_term) { create(:term, vocabulary: facility_vocab) }
    let!(:facility_tagging) { create(:tagging, taggable: school, term: facility_term, context: 'facility') }
    let!(:current_tagging) { create(:tagging, taggable: school, term: create(:term, vocabulary: vocabulary), context: 'curriculum', valid_from: Date.today - 1.year, valid_to: Date.today + 1.year) }
    let!(:expired_tagging) { create(:tagging, taggable: school, term: create(:term, vocabulary: vocabulary), context: 'curriculum', valid_from: Date.today - 2.years, valid_to: Date.today - 1.day) }
    let!(:future_tagging) { create(:tagging, taggable: school, term: create(:term, vocabulary: vocabulary), context: 'curriculum', valid_from: Date.today + 1.day, valid_to: Date.today + 1.year) }

    describe '.by_context' do
      it 'filters taggings by context' do
        expect(Tagging.by_context('curriculum')).to include(curriculum_tagging)
        expect(Tagging.by_context('curriculum')).not_to include(facility_tagging)
      end
    end

    describe '.valid_at' do
      it 'returns currently valid taggings' do
        expect(Tagging.valid_at).to include(current_tagging)
        expect(Tagging.valid_at).not_to include(expired_tagging, future_tagging)
      end

      it 'includes taggings without date restrictions' do
        permanent_tagging = create(:tagging, taggable: school, term: create(:term, vocabulary: vocabulary), context: 'curriculum', valid_from: nil, valid_to: nil)
        expect(Tagging.valid_at).to include(permanent_tagging)
      end
    end

    describe '.for_school' do
      it 'filters taggings by school id' do
        other_school = create(:school)
        other_tagging = create(:tagging, taggable: other_school, term: term, context: 'curriculum')
        
        taggings = Tagging.for_school(school.id)
        expect(taggings).to include(curriculum_tagging, facility_tagging)
        expect(taggings).not_to include(other_tagging)
      end
    end
  end

  describe 'instance methods' do
    describe '#valid_at?' do
      it 'returns true for currently valid tagging' do
        tagging.valid_from = Date.today - 1.month
        tagging.valid_to = Date.today + 1.month
        expect(tagging.valid_at?).to be true
      end

      it 'returns true when no date restrictions' do
        tagging.valid_from = nil
        tagging.valid_to = nil
        expect(tagging.valid_at?).to be true
      end

      it 'returns false for expired tagging' do
        tagging.valid_from = Date.today - 2.months
        tagging.valid_to = Date.today - 1.day
        expect(tagging.valid_at?).to be false
      end

      it 'returns false for future tagging' do
        tagging.valid_from = Date.today + 1.day
        tagging.valid_to = Date.today + 1.month
        expect(tagging.valid_at?).to be false
      end
    end

    describe '#currently_valid?' do
      it 'delegates to valid_at? with current date' do
        expect(tagging).to receive(:valid_at?).with(Date.current)
        tagging.currently_valid?
      end
    end

    describe '#expire!' do
      it 'sets valid_to to current date' do
        tagging.expire!
        expect(tagging.valid_to).to eq(Date.current)
      end

      it 'accepts custom date' do
        custom_date = Date.today - 1.week
        tagging.expire!(custom_date)
        expect(tagging.valid_to).to eq(custom_date)
      end
    end

    describe '#vocabulary' do
      it 'returns term vocabulary' do
        expect(tagging.vocabulary).to eq(vocabulary)
      end
    end
  end


  describe 'factory' do
    it 'creates valid tagging' do
      tagging = build(:tagging, taggable: school, term: term, context: 'curriculum')
      expect(tagging).to be_valid
    end

    it 'creates tagging with validity period' do
      tagging = create(:tagging,
        taggable: school,
        term: term,
        context: 'curriculum',
        valid_from: Date.today,
        valid_to: Date.today + 1.year
      )
      expect(tagging.valid_from).to eq(Date.today)
      expect(tagging.valid_to).to eq(Date.today + 1.year)
    end
  end
end