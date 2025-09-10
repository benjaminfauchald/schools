require 'rails_helper'

RSpec.describe Vocabulary, type: :model do
  let(:vocabulary) { create(:vocabulary, code: 'curriculum', label: 'Curriculum') }

  describe 'associations' do
    it { should have_many(:terms).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:vocabulary) }

    it { should validate_presence_of(:code) }
    it { should validate_presence_of(:label) }
    it { should validate_uniqueness_of(:code) }

  end

  describe 'scopes' do
    describe '.ordered' do
      it 'orders by label' do
        vocab_b = create(:vocabulary, code: 'vocab_b', label: 'B Vocabulary')
        vocab_a = create(:vocabulary, code: 'vocab_a', label: 'A Vocabulary')
        vocab_c = create(:vocabulary, code: 'vocab_c', label: 'C Vocabulary')

        ordered = Vocabulary.ordered
        expect(ordered.index(vocab_a)).to be < ordered.index(vocab_b)
        expect(ordered.index(vocab_b)).to be < ordered.index(vocab_c)
      end
    end
  end

  describe 'instance methods' do
    describe '#active_terms' do
      it 'returns active terms' do
        active = create(:term, vocabulary: vocabulary, is_active: true)
        inactive = create(:term, vocabulary: vocabulary, is_active: false)
        
        expect(vocabulary.active_terms).to include(active)
        expect(vocabulary.active_terms).not_to include(inactive)
      end
    end

    describe '#terms_count' do
      it 'returns count of active terms' do
        create(:term, vocabulary: vocabulary, is_active: true)
        create(:term, vocabulary: vocabulary, is_active: true)
        create(:term, vocabulary: vocabulary, is_active: false)

        expect(vocabulary.terms_count).to eq(2)
      end
    end

    describe '#usage_count' do
      it 'returns count of terms with taggings' do
        school = create(:school)
        term1 = create(:term, vocabulary: vocabulary)
        term2 = create(:term, vocabulary: vocabulary)
        unused_term = create(:term, vocabulary: vocabulary)
        
        create(:tagging, taggable: school, term: term1, context: 'curriculum')
        create(:tagging, taggable: school, term: term2, context: 'curriculum')
        
        expect(vocabulary.usage_count).to eq(2)
      end
    end

    describe '#to_param' do
      it 'uses code for URL generation' do
        expect(vocabulary.to_param).to eq('curriculum')
      end
    end
  end


  describe 'factory' do
    it 'creates valid vocabulary' do
      vocab = build(:vocabulary)
      expect(vocab).to be_valid
    end

    it 'creates unique codes' do
      vocab1 = create(:vocabulary)
      vocab2 = create(:vocabulary)
      expect(vocab1.code).not_to eq(vocab2.code)
    end
  end
end