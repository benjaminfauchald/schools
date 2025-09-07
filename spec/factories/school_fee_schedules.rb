FactoryBot.define do
  factory :school_fee_schedule do
    association :school
    academic_year { "#{Date.current.year}-#{Date.current.year + 1}" }
    currency { 'THB' }
    min_tuition { 100000 }
    max_tuition { 200000 }
    application_fee { 5000 }
    enrollment_fee { 10000 }
    is_published { true }
    grade_level { 'Primary' }
    tuition_fee_thb { 150000 }
    registration_fee_thb { 10000 }

    trait :primary do
      grade_level { 'Primary' }
      min_tuition { 80000 }
      max_tuition { 120000 }
      tuition_fee_thb { 100000 }
    end

    trait :secondary do
      grade_level { 'Secondary' }
      min_tuition { 120000 }
      max_tuition { 180000 }
      tuition_fee_thb { 150000 }
    end

    trait :high_school do
      grade_level { 'High School' }
      min_tuition { 150000 }
      max_tuition { 250000 }
      tuition_fee_thb { 200000 }
    end

    trait :draft do
      is_published { false }
    end

    trait :with_boarding do
      boarding_fee_annual { 200000 }
    end

    trait :with_transport do
      transport_fee_annual { 50000 }
    end

    trait :expensive do
      min_tuition { 300000 }
      max_tuition { 500000 }
      tuition_fee_thb { 400000 }
    end
  end
end
