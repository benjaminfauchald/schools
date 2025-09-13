FactoryBot.define do
  factory :school_fee_band do
    association :school_fee_schedule
    grade_from { 1 }
    grade_to { 5 }
    annual_tuition { 500000 }

    trait :elementary do
      grade_from { 1 }
      grade_to { 5 }
      annual_tuition { 400000 }
    end

    trait :middle_school do
      grade_from { 6 }
      grade_to { 8 }
      annual_tuition { 450000 }
    end

    trait :high_school do
      grade_from { 9 }
      grade_to { 12 }
      annual_tuition { 500000 }
    end
  end
end
