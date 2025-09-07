FactoryBot.define do
  factory :vocabulary do
    sequence(:code) { |n| "vocabulary_#{n}" }
    sequence(:label) { |n| "Vocabulary #{n}" }
    description { Faker::Lorem.sentence }

    trait :curriculum do
      code { 'curriculum' }
      label { 'Curriculum' }
      description { 'Educational curriculum and programs' }
    end

    trait :facility do
      code { 'facility' }
      label { 'Facilities' }
      description { 'Campus facilities and amenities' }
    end

    trait :language do
      code { 'language' }
      label { 'Languages' }
      description { 'Languages of instruction' }
    end

    trait :accreditation do
      code { 'accreditation' }
      label { 'Accreditations' }
      description { 'School accreditations and certifications' }
    end

    trait :extracurricular do
      code { 'extracurricular' }
      label { 'Extracurricular Activities' }
      description { 'After-school and extracurricular programs' }
    end

    trait :program do
      code { 'program' }
      label { 'Programs' }
      description { 'Special programs and offerings' }
    end
  end
end
