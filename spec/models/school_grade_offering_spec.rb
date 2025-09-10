require 'rails_helper'

RSpec.describe SchoolGradeOffering, type: :model do
  # CRITICAL BUSINESS LOGIC TEST: Grade offerings are essential for parent decision-making
  # This test protects against regressions in:
  # 1. Age eligibility calculations that parents rely on to find suitable schools
  # 2. Grade level mapping that affects search and filtering
  # 3. School categorization (early years, elementary, secondary)
  # 4. Enrollment eligibility checks that determine if a child can attend
  # Without proper grade offering logic, parents can't find appropriate schools for their children!

  describe "#complete_grade_offering_workflow" do
    it "correctly manages age ranges and grade levels for parent school selection" do
      school = create(:school, name: "International Academy Bangkok")

      # Create a comprehensive K-12 school offering
      grade_offering = create(:school_grade_offering,
        school: school,
        min_age: 3.5,        # Nursery/Pre-K
        max_age: 18,         # Grade 12/Senior
        grades: "Nursery - Grade 12",
        notes: "Full K-12 international curriculum"
      )

      # TEST 1: Verify age range display for parents
      expect(grade_offering.age_range_display).to eq("Ages 3-18")

      # TEST 2: Verify grades display
      expect(grade_offering.grades_display).to eq("Nursery - Grade 12")

      # TEST 3: Verify school serves all education levels
      expect(grade_offering.serves_early_years?).to be true   # Under 6
      expect(grade_offering.serves_elementary?).to be true    # 5-12
      expect(grade_offering.serves_secondary?).to be true     # 13+

      # TEST 4: Verify parent can check if their child's age is eligible
      expect(grade_offering.accepts_age?(4)).to be true    # 4-year-old
      expect(grade_offering.accepts_age?(10)).to be true   # 10-year-old
      expect(grade_offering.accepts_age?(16)).to be true   # 16-year-old
      expect(grade_offering.accepts_age?(2)).to be false   # Too young
      expect(grade_offering.accepts_age?(19)).to be false  # Too old

      # TEST 5: Verify school type categorization
      expect(grade_offering.school_type).to eq("K-12")  # Full range school

      # TEST 6: Test elementary-only school
      elementary_school = create(:school, name: "Bangkok Elementary")
      elementary_offering = create(:school_grade_offering,
        school: elementary_school,
        min_age: 5,
        max_age: 11,
        grades: "K-5"
      )

      expect(elementary_offering.serves_early_years?).to be false
      expect(elementary_offering.serves_elementary?).to be true
      expect(elementary_offering.serves_secondary?).to be false
      expect(elementary_offering.school_type).to eq("Elementary")

      # TEST 7: Test early years only school
      preschool = create(:school, name: "Little Learners Preschool")
      preschool_offering = create(:school_grade_offering,
        school: preschool,
        min_age: 2,
        max_age: 5,
        grades: "Nursery - Kindergarten"
      )

      expect(preschool_offering.serves_early_years?).to be true
      expect(preschool_offering.serves_elementary?).to be false
      expect(preschool_offering.serves_secondary?).to be false
      expect(preschool_offering.school_type).to eq("Early Years")

      # TEST 8: Verify grade estimation when grades field is empty
      school_without_grades = create(:school)
      offering_without_grades = create(:school_grade_offering,
        school: school_without_grades,
        min_age: 6,
        max_age: 14,
        grades: nil  # No explicit grades specified
      )

      # Should estimate grades from ages (age 6 ≈ Grade 1, age 14 ≈ Grade 9)
      expect(offering_without_grades.grades_display).to eq("Grades 1-9")

      # TEST 9: Verify scope queries work for finding schools by level
      expect(SchoolGradeOffering.early_years).to include(preschool_offering)
      expect(SchoolGradeOffering.early_years).not_to include(elementary_offering)

      expect(SchoolGradeOffering.elementary).to include(elementary_offering)
      expect(SchoolGradeOffering.elementary).not_to include(preschool_offering)

      expect(SchoolGradeOffering.full_range).to include(grade_offering)
      expect(SchoolGradeOffering.full_range).not_to include(elementary_offering, preschool_offering)

      # TEST 10: Verify association with school
      expect(school.school_grade_offering).to eq(grade_offering)
      expect(grade_offering.school).to eq(school)
    end
  end

  describe "business rule validations" do
    it "enforces that max age must be greater than min age" do
      offering = build(:school_grade_offering,
        min_age: 10,
        max_age: 5  # Invalid: less than min
      )

      expect(offering).not_to be_valid
      expect(offering.errors[:max_age]).to include("must be greater than minimum age")
    end

    it "enforces unique grade offering per school" do
      school = create(:school)
      existing = create(:school_grade_offering, school: school)

      duplicate = build(:school_grade_offering, school: school)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:school_id]).to include("has already been taken")
    end

    it "enforces reasonable age limits" do
      offering = build(:school_grade_offering,
        min_age: -1,  # Invalid: negative
        max_age: 30   # Invalid: too high
      )

      expect(offering).not_to be_valid
      expect(offering.errors[:min_age]).to include("must be greater than 0")
      expect(offering.errors[:max_age]).to include("must be less than 25")
    end

    it "allows decimal ages for precise enrollment cutoffs" do
      offering = build(:school_grade_offering,
        min_age: 2.5,  # 2 years 6 months
        max_age: 18.5  # 18 years 6 months
      )

      expect(offering).to be_valid
      expect(offering.age_range_display).to eq("Ages 2-18")  # Display rounds down
    end
  end

  describe "edge cases and parent search scenarios" do
    it "handles schools with no age restrictions gracefully" do
      school = create(:school)
      offering = create(:school_grade_offering,
        school: school,
        min_age: nil,
        max_age: nil,
        grades: "All ages welcome"
      )

      expect(offering.age_range_display).to eq("Ages not specified")
      expect(offering.serves_early_years?).to be false
      expect(offering.serves_elementary?).to be false
      expect(offering.accepts_age?(10)).to be true  # Accepts any age when not specified
    end

    it "handles single-grade schools correctly" do
      school = create(:school, name: "Grade 12 Exam Prep Center")
      offering = create(:school_grade_offering,
        school: school,
        min_age: 17,
        max_age: 17,
        grades: "Grade 12 only"
      )

      expect(offering.age_range_display).to eq("Age 17")
      expect(offering.accepts_age?(17)).to be true
      expect(offering.accepts_age?(16)).to be false
      expect(offering.accepts_age?(18)).to be false
    end

    it "correctly categorizes international vs local curriculum schools" do
      # International schools often start earlier (age 3) and go to 18
      international_school = create(:school)
      international_offering = create(:school_grade_offering,
        school: international_school,
        min_age: 3,
        max_age: 18
      )

      # Thai schools typically start at 6 and go to 18
      thai_school = create(:school)
      thai_offering = create(:school_grade_offering,
        school: thai_school,
        min_age: 6,
        max_age: 18
      )

      expect(international_offering.serves_early_years?).to be true
      expect(thai_offering.serves_early_years?).to be false

      # Both serve K-12 but international includes pre-K
      expect(international_offering.education_levels).to include("Pre-K", "Elementary", "Secondary")
      expect(thai_offering.education_levels).to include("Elementary", "Secondary")
      expect(thai_offering.education_levels).not_to include("Pre-K")
    end

    it "supports filtering schools by child's age for parent searches" do
      # Parent has a 4-year-old child
      child_age = 4

      # Create various schools
      preschool = create(:school_grade_offering, min_age: 2, max_age: 5)
      elementary = create(:school_grade_offering, min_age: 6, max_age: 11)
      k12_school = create(:school_grade_offering, min_age: 3, max_age: 18)
      high_school = create(:school_grade_offering, min_age: 13, max_age: 18)

      # Find schools that accept 4-year-olds
      suitable_schools = SchoolGradeOffering.accepting_age(child_age)

      expect(suitable_schools).to include(preschool, k12_school)
      expect(suitable_schools).not_to include(elementary, high_school)
    end
  end

  describe "grade level mapping for search filters" do
    it "correctly maps Thai education system grades" do
      # Thai system: Anuban (K), Prathom (P1-6), Matthayom (M1-6)
      thai_primary = create(:school_grade_offering,
        min_age: 6,
        max_age: 11,
        grades: "Prathom 1-6"
      )

      thai_secondary = create(:school_grade_offering,
        min_age: 12,
        max_age: 17,
        grades: "Matthayom 1-6"
      )

      expect(thai_primary.thai_grade_level).to eq("Prathom")
      expect(thai_secondary.thai_grade_level).to eq("Matthayom")
    end

    it "correctly maps international curriculum grades" do
      # British system: Reception, Primary (Y1-6), Secondary (Y7-13)
      british_primary = create(:school_grade_offering,
        min_age: 4,
        max_age: 11,
        grades: "Reception - Year 6"
      )

      # American system: Elementary (K-5), Middle (6-8), High (9-12)
      american_middle = create(:school_grade_offering,
        min_age: 11,
        max_age: 14,
        grades: "Grades 6-8"
      )

      expect(british_primary.curriculum_type).to include("British")
      expect(american_middle.curriculum_type).to include("American")
    end
  end
end
