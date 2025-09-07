FactoryBot.define do
  factory :school_grade_offering do
    association :school
    min_age { 3 }
    max_age { 18 }
    grades { 'K-12' }
    grades_display { 'Kindergarten to Grade 12' }
    educational_level { 'K-12' }

    trait :early_years do
      min_age { 2 }
      max_age { 6 }
      grades { 'Pre-K to K' }
      grades_display { 'Pre-Kindergarten to Kindergarten' }
      educational_level { 'Early Years' }
    end

    trait :elementary do
      min_age { 5 }
      max_age { 12 }
      grades { 'K-6' }
      grades_display { 'Kindergarten to Grade 6' }
      educational_level { 'Elementary' }
    end

    trait :middle_school do
      min_age { 11 }
      max_age { 14 }
      grades { '7-9' }
      grades_display { 'Grade 7 to Grade 9' }
      educational_level { 'Middle School' }
    end

    trait :high_school do
      min_age { 14 }
      max_age { 18 }
      grades { '10-12' }
      grades_display { 'Grade 10 to Grade 12' }
      educational_level { 'High School' }
    end

    trait :full_range do
      min_age { 3 }
      max_age { 18 }
      grades { 'Pre-K to 12' }
      grades_display { 'Pre-Kindergarten to Grade 12' }
      educational_level { 'Pre-K to 12' }
    end

    trait :preschool_only do
      min_age { 2 }
      max_age { 5 }
      grades { 'Pre-K' }
      grades_display { 'Pre-Kindergarten' }
      educational_level { 'Preschool' }
    end
  end
end
