require 'rails_helper'

# This test protects the CRITICAL school filtering by attributes business logic
# that allows parents to find schools matching their specific requirements.
# Without proper filtering by curriculum, facilities, grade levels, and amenities,
# parents cannot effectively search for schools that meet their children's needs.
# This test ensures the filtering logic accurately matches schools by their attributes.

RSpec.describe 'School Filtering by Attributes Business Logic', type: :model do
  describe 'comprehensive school filtering by curricula, facilities, and services' do
    # Create vocabularies for taxonomy
    let!(:curriculum_vocab) { Vocabulary.find_or_create_by(code: 'curriculum') { |v| v.label = 'Curriculum' } }
    let!(:facility_vocab) { Vocabulary.find_or_create_by(code: 'facility') { |v| v.label = 'Facilities' } }
    let!(:language_vocab) { Vocabulary.find_or_create_by(code: 'language') { |v| v.label = 'Languages' } }
    let!(:program_vocab) { Vocabulary.find_or_create_by(code: 'program') { |v| v.label = 'Programs' } }

    # Create terms for curricula
    let!(:british_curriculum) { create(:term, vocabulary: curriculum_vocab, label: 'British', slug: 'british') }
    let!(:american_curriculum) { create(:term, vocabulary: curriculum_vocab, label: 'American', slug: 'american') }
    let!(:ib_curriculum) { create(:term, vocabulary: curriculum_vocab, label: 'IB', slug: 'ib') }
    let!(:thai_curriculum) { create(:term, vocabulary: curriculum_vocab, label: 'Thai National', slug: 'thai-national') }

    # Create terms for facilities
    let!(:swimming_pool) { create(:term, vocabulary: facility_vocab, label: 'Swimming Pool', slug: 'swimming-pool') }
    let!(:library) { create(:term, vocabulary: facility_vocab, label: 'Library', slug: 'library') }
    let!(:sports_field) { create(:term, vocabulary: facility_vocab, label: 'Sports Field', slug: 'sports-field') }
    let!(:science_lab) { create(:term, vocabulary: facility_vocab, label: 'Science Lab', slug: 'science-lab') }
    let!(:art_studio) { create(:term, vocabulary: facility_vocab, label: 'Art Studio', slug: 'art-studio') }
    let!(:music_room) { create(:term, vocabulary: facility_vocab, label: 'Music Room', slug: 'music-room') }

    # Create terms for languages
    let!(:english_language) { create(:term, vocabulary: language_vocab, label: 'English', slug: 'english') }
    let!(:thai_language) { create(:term, vocabulary: language_vocab, label: 'Thai', slug: 'thai') }
    let!(:chinese_language) { create(:term, vocabulary: language_vocab, label: 'Chinese', slug: 'chinese') }

    # Create terms for programs
    let!(:stem_program) { create(:term, vocabulary: program_vocab, label: 'STEM', slug: 'stem') }
    let!(:arts_program) { create(:term, vocabulary: program_vocab, label: 'Arts', slug: 'arts') }
    let!(:sports_program) { create(:term, vocabulary: program_vocab, label: 'Sports', slug: 'sports') }

    it 'filters schools by multiple attributes and returns accurate results' do
      # PART 1: Create diverse schools with different attributes

      # Elite international school with everything
      elite_school = create(:school,
        name: 'Elite International Academy',
        boarding: true,
        school_bus: true,
        status: 'published'
      )
      elite_school.add_term(british_curriculum)
      elite_school.add_term(ib_curriculum)
      elite_school.add_term(swimming_pool)
      elite_school.add_term(library)
      elite_school.add_term(science_lab)
      elite_school.add_term(english_language)
      elite_school.add_term(stem_program)
      create(:school_grade_offering,
        school: elite_school,
        min_age: 3,
        max_age: 18,
        grades: 'K-12'
      )

      # Budget local school with basics
      budget_school = create(:school,
        name: 'Budget Local School',
        boarding: false,
        school_bus: true,
        status: 'published'
      )
      budget_school.add_term(thai_curriculum)
      budget_school.add_term(library)
      budget_school.add_term(thai_language)
      create(:school_grade_offering,
        school: budget_school,
        min_age: 6,
        max_age: 12,
        grades: 'Grade 1-6'
      )

      # STEM-focused school
      stem_school = create(:school,
        name: 'STEM Academy Bangkok',
        boarding: false,
        school_bus: true,
        status: 'published'
      )
      stem_school.add_term(american_curriculum)
      stem_school.add_term(science_lab)
      stem_school.add_term(library)
      stem_school.add_term(english_language)
      stem_school.add_term(stem_program)
      create(:school_grade_offering,
        school: stem_school,
        min_age: 11,
        max_age: 18,
        grades: 'Grade 6-12'
      )

      # Arts-focused school
      arts_school = create(:school,
        name: 'Creative Arts International',
        boarding: true,
        school_bus: false,
        status: 'published'
      )
      arts_school.add_term(ib_curriculum)
      arts_school.add_term(art_studio)
      arts_school.add_term(music_room)
      arts_school.add_term(library)
      arts_school.add_term(english_language)
      arts_school.add_term(arts_program)
      create(:school_grade_offering,
        school: arts_school,
        min_age: 5,
        max_age: 18,
        grades: 'K-12'
      )

      # Sports-focused school
      sports_school = create(:school,
        name: 'Sports Excellence School',
        boarding: true,
        school_bus: true,
        status: 'published'
      )
      sports_school.add_term(british_curriculum)
      sports_school.add_term(swimming_pool)
      sports_school.add_term(sports_field)
      sports_school.add_term(english_language)
      sports_school.add_term(sports_program)
      create(:school_grade_offering,
        school: sports_school,
        min_age: 8,
        max_age: 18,
        grades: 'Grade 3-12'
      )

      # Draft school (should never appear in results)
      draft_school = create(:school,
        name: 'Draft School Not Ready',
        status: 'draft'
      )
      draft_school.add_term(british_curriculum)
      draft_school.add_term(swimming_pool)

      # PART 2: Test filtering by single curriculum

      british_schools = School.published.joins(:taggings)
        .where(taggings: { term: british_curriculum })
        .select('schools.id, schools.name')
        .distinct

      expect(british_schools.map(&:name)).to contain_exactly(
        'Elite International Academy',
        'Sports Excellence School'
      )

      # PART 3: Test filtering by multiple facilities (schools with ALL specified facilities)

      schools_with_pool_and_library = School.published
        .joins(:taggings)
        .where(taggings: { term: [ swimming_pool, library ] })
        .group('schools.id')
        .having('COUNT(DISTINCT taggings.term_id) = ?', 2)

      expect(schools_with_pool_and_library.map(&:name)).to contain_exactly(
        'Elite International Academy'
      )

      # PART 4: Test filtering by boarding availability

      boarding_schools = School.published.with_boarding

      expect(boarding_schools.map(&:name)).to contain_exactly(
        'Elite International Academy',
        'Creative Arts International',
        'Sports Excellence School'
      )

      # PART 5: Test filtering by school bus service

      bus_schools = School.published.with_school_bus

      expect(bus_schools.map(&:name)).to contain_exactly(
        'Elite International Academy',
        'Budget Local School',
        'STEM Academy Bangkok',
        'Sports Excellence School'
      )

      # PART 6: Test filtering by age range

      # Schools accepting 5-year-olds
      schools_for_age_5 = School.published
        .joins(:school_grade_offering)
        .where('school_grade_offerings.min_age <= ? AND school_grade_offerings.max_age >= ?', 5, 5)

      expect(schools_for_age_5.map(&:name)).to contain_exactly(
        'Elite International Academy',
        'Creative Arts International'
      )

      # Schools for teenagers (age 14)
      schools_for_age_14 = School.published
        .joins(:school_grade_offering)
        .where('school_grade_offerings.min_age <= ? AND school_grade_offerings.max_age >= ?', 14, 14)

      expect(schools_for_age_14.map(&:name)).to contain_exactly(
        'Elite International Academy',
        'STEM Academy Bangkok',
        'Creative Arts International',
        'Sports Excellence School'
      )

      # PART 7: Test complex multi-attribute filtering

      # Parent wants: British curriculum + Swimming pool + Boarding + Ages 10-16
      complex_filter = School.published
        .joins(:taggings, :school_grade_offering)
        .where(boarding: true)
        .where(taggings: { term: [ british_curriculum, swimming_pool ] })
        .where('school_grade_offerings.min_age <= ? AND school_grade_offerings.max_age >= ?', 10, 16)
        .group('schools.id')
        .having('COUNT(DISTINCT taggings.term_id) >= ?', 2)

      expect(complex_filter.map(&:name)).to contain_exactly(
        'Elite International Academy',
        'Sports Excellence School'
      )

      # PART 8: Test filtering by program focus

      stem_focused = School.published
        .joins(:taggings)
        .where(taggings: { term: stem_program })
        .select('schools.id, schools.name')
        .distinct

      expect(stem_focused.map(&:name)).to contain_exactly(
        'Elite International Academy',
        'STEM Academy Bangkok'
      )

      # PART 9: Test combining curriculum and facilities

      # IB schools with art facilities
      ib_with_arts = School.published
        .joins(:taggings)
        .where(taggings: { term: [ ib_curriculum, art_studio ] })
        .group('schools.id')
        .having('COUNT(DISTINCT taggings.term_id) = ?', 2)

      expect(ib_with_arts.map(&:name)).to contain_exactly(
        'Creative Arts International'
      )

      # PART 10: Test has_term? helper method

      expect(elite_school.has_term?('british', context: 'curriculum')).to be true
      expect(elite_school.has_term?('american', context: 'curriculum')).to be false
      expect(elite_school.has_term?(swimming_pool)).to be true
      expect(elite_school.has_term?('sports-field', context: 'facility')).to be false

      # PART 11: Test term collections

      expect(elite_school.curricula.map(&:slug)).to contain_exactly('british', 'ib')
      expect(elite_school.facilities.map(&:slug)).to contain_exactly(
        'swimming-pool', 'library', 'science-lab'
      )
      expect(stem_school.programs.map(&:slug)).to contain_exactly('stem')

      # PART 12: Ensure draft schools never appear in results

      all_filters = [
        School.published,
        School.published.with_boarding,
        School.published.with_school_bus,
        School.published.joins(:taggings).where(taggings: { term: british_curriculum })
      ]

      all_filters.each do |filtered_schools|
        expect(filtered_schools.map(&:name)).not_to include('Draft School Not Ready')
      end
    end

    it 'provides accurate counts for filter combinations' do
      # Create schools for count testing
      5.times do |i|
        school = create(:school, name: "British School #{i}", status: 'published', boarding: i.even?)
        school.add_term(british_curriculum)
        school.add_term(library) if i < 3
      end

      3.times do |i|
        school = create(:school, name: "American School #{i}", status: 'published', boarding: true)
        school.add_term(american_curriculum)
        school.add_term(swimming_pool)
      end

      # Count British schools
      british_count = School.published
        .joins(:taggings)
        .where(taggings: { term: british_curriculum })
        .select('schools.id')
        .distinct
        .count

      expect(british_count).to eq 5

      # Count schools with boarding
      boarding_count = School.published.with_boarding.count
      expect(boarding_count).to eq 6 # 3 British (even indexed) + 3 American

      # Count British schools with library
      british_with_library = School.published
        .joins(:taggings)
        .where(taggings: { term: [ british_curriculum, library ] })
        .group('schools.id')
        .having('COUNT(DISTINCT taggings.term_id) = ?', 2)
        .count

      expect(british_with_library.size).to eq 3
    end
  end
end
