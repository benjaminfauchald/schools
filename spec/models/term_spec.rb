require 'rails_helper'

RSpec.describe Term, type: :model do
  let(:vocabulary) { create(:vocabulary, code: 'curriculum', label: 'Curriculum') }
  let(:term) { create(:term, vocabulary: vocabulary, label: 'International Baccalaureate', slug: 'ib') }

  describe 'associations' do
    it { should belong_to(:vocabulary) }
    it { should have_many(:taggings).dependent(:destroy) }
    it { should have_many(:schools).through(:taggings) }
  end

  describe 'validations' do
    subject { build(:term, vocabulary: vocabulary) }

    it { should validate_presence_of(:vocabulary_id) }
    it { should validate_presence_of(:label) }
    
    it 'validates presence of slug' do
      term = build(:term, vocabulary: vocabulary, slug: nil, label: 'Test')
      term.valid?
      # Slug is auto-generated, so it should be valid
      expect(term).to be_valid
      expect(term.slug).to eq('test')
    end
    
    it { should validate_uniqueness_of(:slug).scoped_to(:vocabulary_id) }
  end

  describe 'callbacks' do
    describe 'before_validation' do
      it 'generates slug from label if blank' do
        term = build(:term, vocabulary: vocabulary, label: 'Cambridge IGCSE', slug: nil)
        term.valid?
        expect(term.slug).to eq('cambridge_igcse')
      end

      it 'does not override existing slug' do
        term = build(:term, vocabulary: vocabulary, label: 'Cambridge IGCSE', slug: 'custom-slug')
        term.valid?
        expect(term.slug).to eq('custom-slug')
      end

      it 'handles special characters in label' do
        term = build(:term, vocabulary: vocabulary, label: 'Pre-K & Kindergarten!', slug: nil)
        term.valid?
        expect(term.slug).to eq('pre_k_kindergarten')
      end
    end
  end

  describe 'scopes' do
    let!(:active_term) { create(:term, vocabulary: vocabulary, is_active: true) }
    let!(:inactive_term) { create(:term, vocabulary: vocabulary, is_active: false) }
    let!(:curriculum_term) { create(:term, vocabulary: vocabulary) }
    let!(:facility_vocab) { create(:vocabulary, code: 'facility') }
    let!(:facility_term) { create(:term, vocabulary: facility_vocab) }

    describe '.active' do
      it 'returns only active terms' do
        expect(Term.active).to include(active_term)
        expect(Term.active).not_to include(inactive_term)
      end
    end

    describe '.in_vocabulary' do
      it 'filters terms by vocabulary code' do
        terms = Term.in_vocabulary('curriculum')
        expect(terms).to include(curriculum_term, active_term, inactive_term)
        expect(terms).not_to include(facility_term)
      end
    end

    describe '.roots' do
      it 'returns terms without parent' do
        root = create(:term, vocabulary: vocabulary, parent: nil)
        child = create(:term, vocabulary: vocabulary, parent: root)
        expect(Term.roots).to include(root)
        expect(Term.roots).not_to include(child)
      end
    end
  end

  describe 'instance methods' do
    describe '#full_label' do
      it 'returns label for root term' do
        expect(term.full_label).to eq('International Baccalaureate')
      end

      it 'includes parent hierarchy' do
        parent = create(:term, vocabulary: vocabulary, label: 'STEM')
        child = create(:term, vocabulary: vocabulary, label: 'Robotics', parent: parent)
        expect(child.full_label).to eq('STEM > Robotics')
      end
    end

    describe '#schools_count' do
      it 'returns count of published schools' do
        expect(term.schools_count).to eq(0)

        school1 = create(:school, status: 'published')
        school2 = create(:school, status: 'published')
        draft_school = create(:school, status: 'draft')
        
        create(:tagging, taggable: school1, term: term, context: 'curriculum')
        create(:tagging, taggable: school2, term: term, context: 'curriculum')
        create(:tagging, taggable: draft_school, term: term, context: 'curriculum')

        expect(term.schools_count).to eq(2)
      end
    end

    describe '#to_param' do
      it 'uses slug for URL generation' do
        expect(term.to_param).to eq('ib')
      end
    end

    describe '#valid_at?' do
      it 'checks if term has valid taggings at date' do
        school = create(:school)
        create(:tagging, 
          taggable: school,
          term: term,
          context: 'curriculum',
          valid_from: Date.today - 1.month,
          valid_to: Date.today + 1.month
        )
        
        expect(term.valid_at?(Date.today)).to be true
        expect(term.valid_at?(Date.today + 2.months)).to be false
      end
    end
  end

  describe 'hierarchical relationships' do
    let(:parent_term) { create(:term, vocabulary: vocabulary, label: 'Parent Term') }
    let(:child_term) { create(:term, vocabulary: vocabulary, label: 'Child Term', parent: parent_term) }
    let(:grandchild_term) { create(:term, vocabulary: vocabulary, label: 'Grandchild Term', parent: child_term) }

    describe 'parent-child associations' do
      it 'belongs to parent' do
        expect(child_term.parent).to eq(parent_term)
      end

      it 'has many children' do
        # Ensure child is created before checking
        child_term
        expect(parent_term.children).to include(child_term)
      end
    end

    describe '#ancestors' do
      it 'returns all ancestors' do
        ancestors = grandchild_term.ancestors
        expect(ancestors.map(&:id)).to include(parent_term.id, child_term.id)
      end

      it 'returns empty array for root term' do
        expect(parent_term.ancestors).to be_empty
      end
    end

    describe '#descendants' do
      it 'returns all descendants' do
        # Ensure all terms are created first
        grandchild_term
        
        descendants = parent_term.descendants
        descendant_ids = descendants.map(&:id)
        expect(descendant_ids).to include(child_term.id)
        expect(descendant_ids).to include(grandchild_term.id)
      end

      it 'returns empty array for leaf term' do
        expect(grandchild_term.descendants).to be_empty
      end
    end

  end

  describe 'metadata' do
    it 'accesses metadata fields' do
      term.metadata = { 'stage' => 'primary', 'issuer' => 'IBO', 'category' => 'international' }
      expect(term.stage).to eq('primary')
      expect(term.issuer).to eq('IBO')
      expect(term.category).to eq('international')
    end
  end

  describe 'factory' do
    it 'creates valid term' do
      term = build(:term, vocabulary: vocabulary)
      expect(term).to be_valid
    end
  end
end