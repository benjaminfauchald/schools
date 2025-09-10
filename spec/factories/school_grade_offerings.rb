FactoryBot.define do
  factory :school_grade_offering do
    association :school
    min_age { 3 }
    max_age { 18 }
    grades { 'K-12' }

    trait :early_years do
      min_age { 2 }
      max_age { 6 }
      grades { 'Pre-K to K' }
    end

    trait :elementary do
      min_age { 5 }
      max_age { 12 }
      grades { 'K-6' }
    end

    trait :middle_school do
      min_age { 11 }
      max_age { 14 }
      grades { '7-9' }
    end

    trait :high_school do
      min_age { 14 }
      max_age { 18 }
      grades { '10-12' }
    end

    trait :full_range do
      min_age { 3 }
      max_age { 18 }
      grades { 'Pre-K to 12' }
    end

    trait :preschool_only do
      min_age { 2 }
      max_age { 5 }
      grades { 'Pre-K' }
    end
  end
end
