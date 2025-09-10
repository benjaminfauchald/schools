require 'rails_helper'

RSpec.describe SchoolFeeSchedule, type: :model do
  # CRITICAL BUSINESS LOGIC TEST: Fee schedules are essential for school operations
  # This test protects against regressions in:
  # 1. Fee calculation and display logic
  # 2. Academic year management
  # 3. Fee structure validation
  # 4. Total cost calculations that parents rely on for budgeting
  # Without proper fee display, schools can't communicate pricing to prospective families!

  describe "#complete_fee_calculation_workflow" do
    it "correctly calculates and displays all fee components for parent decision-making" do
      school = create(:school, name: "Premium International School")

      # Create a comprehensive fee schedule with all possible fees
      fee_schedule = create(:school_fee_schedule,
        school: school,
        academic_year: "2024/2025",
        currency: "THB",
        min_tuition: 250000,      # 250,000 THB minimum
        max_tuition: 500000,      # 500,000 THB maximum
        application_fee: 5000,    # One-time
        enrollment_fee: 50000,    # One-time
        capital_levy: 100000,     # One-time
        boarding_fee_annual: 200000,  # Annual
        transport_fee_annual: 35000,  # Annual
        notes: "Early bird discount available",
        is_published: true
      )

      # TEST 1: Verify tuition range display formatting
      expect(fee_schedule.tuition_range_display).to eq("250,000 - 500,000 THB")

      # TEST 2: Verify one-time fees calculation
      one_time = fee_schedule.one_time_fees
      expect(one_time[:application_fee]).to eq(5000)
      expect(one_time[:enrollment_fee]).to eq(50000)
      expect(one_time[:capital_levy]).to eq(100000)

      # TEST 3: Verify annual fees calculation
      annual = fee_schedule.annual_fees
      expect(annual[:boarding_fee]).to eq(200000)
      expect(annual[:transport_fee]).to eq(35000)

      # TEST 4: Verify total first-year cost calculation (critical for parents)
      # This would be: max_tuition + all one-time fees + all annual fees
      total_first_year = fee_schedule.calculate_total_first_year_cost(:maximum)
      expected_total = 500000 + 5000 + 50000 + 100000 + 200000 + 35000
      expect(total_first_year).to eq(expected_total) # 890,000 THB

      # TEST 5: Verify minimum first-year cost calculation
      min_first_year = fee_schedule.calculate_total_first_year_cost(:minimum)
      expected_min = 250000 + 5000 + 50000 + 100000 # Tuition + required one-time fees
      expect(min_first_year).to eq(expected_min) # 405,000 THB

      # TEST 6: Verify formatted display for UI
      expect(fee_schedule.formatted_total_range).to include("405,000")
      expect(fee_schedule.formatted_total_range).to include("890,000")

      # TEST 7: Verify academic year detection
      allow(Date).to receive(:current).and_return(Date.new(2024, 8, 1))
      expect(fee_schedule.current_year?).to be true

      allow(Date).to receive(:current).and_return(Date.new(2026, 1, 1))
      expect(fee_schedule.current_year?).to be false

      # TEST 8: Verify fee schedule is associated with correct school
      expect(fee_schedule.school).to eq(school)
      expect(school.school_fee_schedules).to include(fee_schedule)

      # TEST 9: Verify published scope works correctly
      unpublished = create(:school_fee_schedule,
        school: school,
        academic_year: "2025/2026",
        is_published: false
      )

      expect(SchoolFeeSchedule.published).to include(fee_schedule)
      expect(SchoolFeeSchedule.published).not_to include(unpublished)

      # TEST 10: Verify currency is preserved and displayed
      usd_schedule = create(:school_fee_schedule,
        school: school,
        academic_year: "2024/2025 USD",
        currency: "USD",
        min_tuition: 8000,
        max_tuition: 15000
      )
      expect(usd_schedule.tuition_range_display).to include("USD")
      expect(usd_schedule.tuition_range_display).not_to include("THB")
    end
  end

  describe "business rule validations" do
    it "enforces that max tuition must be greater than or equal to min tuition" do
      schedule = build(:school_fee_schedule,
        min_tuition: 500000,
        max_tuition: 250000  # Invalid: less than min
      )

      expect(schedule).not_to be_valid
      expect(schedule.errors[:max_tuition]).to include("must be greater than or equal to minimum tuition")
    end

    it "prevents duplicate academic years for the same school" do
      school = create(:school)
      existing = create(:school_fee_schedule,
        school: school,
        academic_year: "2024/2025"
      )

      duplicate = build(:school_fee_schedule,
        school: school,
        academic_year: "2024/2025"  # Same year
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:academic_year]).to include("has already been taken")

      # But allows same year for different school
      other_school = create(:school)
      other_schedule = build(:school_fee_schedule,
        school: other_school,
        academic_year: "2024/2025"
      )
      expect(other_schedule).to be_valid
    end

    it "requires positive amounts for tuition fees" do
      schedule = build(:school_fee_schedule,
        min_tuition: -1000,
        max_tuition: 0
      )

      expect(schedule).not_to be_valid
      expect(schedule.errors[:min_tuition]).to include("must be greater than 0")
      expect(schedule.errors[:max_tuition]).to include("must be greater than 0")
    end

    it "allows zero or positive amounts for additional fees" do
      schedule = build(:school_fee_schedule,
        application_fee: 0,      # Valid: can be free
        enrollment_fee: 10000,   # Valid: positive
        transport_fee_annual: -1000  # Invalid: negative
      )

      expect(schedule).not_to be_valid
      expect(schedule.errors[:transport_fee_annual]).to include("must be greater than or equal to 0")
      expect(schedule.errors[:application_fee]).to be_empty
      expect(schedule.errors[:enrollment_fee]).to be_empty
    end
  end

  describe "edge cases and data integrity" do
    it "handles schools with no fees gracefully" do
      school = create(:school)

      # School with no fee schedules
      expect(school.school_fee_schedules).to be_empty
      expect { school.school_fee_schedules.first&.tuition_range_display }.not_to raise_error
    end

    it "correctly formats very large fee amounts" do
      schedule = create(:school_fee_schedule,
        min_tuition: 1000000,   # 1 million
        max_tuition: 10000000   # 10 million
      )

      # Should format with proper thousand separators
      expect(schedule.tuition_range_display).to eq("1,000,000 - 10,000,000 THB")
    end

    it "handles single tuition amount (min equals max)" do
      schedule = create(:school_fee_schedule,
        min_tuition: 300000,
        max_tuition: 300000  # Same as min
      )

      # Should show single amount, not range
      expect(schedule.tuition_range_display).to eq("300,000 THB")
    end

    it "handles partial fee schedules with missing optional fees" do
      schedule = create(:school_fee_schedule,
        min_tuition: 200000,
        max_tuition: 200000,
        application_fee: 5000,
        enrollment_fee: nil,      # Not specified
        boarding_fee_annual: nil, # Not offered
        transport_fee_annual: nil # Not offered
      )

      expect(schedule).to be_valid

      # Only calculates with provided fees
      total = schedule.calculate_total_first_year_cost(:minimum)
      expect(total).to eq(205000) # Just tuition + application
    end
  end

  describe "current academic year scope" do
    it "correctly identifies schedules for the current academic year" do
      current_year = Date.current.year

      # Various academic year formats schools might use
      current_schedule1 = create(:school_fee_schedule,
        academic_year: "#{current_year}/#{current_year + 1}")
      current_schedule2 = create(:school_fee_schedule,
        academic_year: "#{current_year - 1}/#{current_year}")
      future_schedule = create(:school_fee_schedule,
        academic_year: "#{current_year + 1}/#{current_year + 2}")
      past_schedule = create(:school_fee_schedule,
        academic_year: "#{current_year - 2}/#{current_year - 1}")

      current_scope = SchoolFeeSchedule.current_academic_year

      expect(current_scope).to include(current_schedule1, current_schedule2)
      expect(current_scope).not_to include(future_schedule, past_schedule)
    end
  end
end
