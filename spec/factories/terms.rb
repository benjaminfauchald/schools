FactoryBot.define do
  factory :term do
    association :vocabulary
    sequence(:slug) { |n| "term_#{n}" }
    sequence(:label) { |n| "Term #{n}" }
    description { Faker::Lorem.sentence }
    is_active { true }
    metadata { {} }

    trait :with_parent do
      association :parent, factory: :term
    end

    trait :inactive do
      is_active { false }
    end

    # Curriculum terms
    trait :ib_programme do
      slug { 'ib' }
      label { 'IB Programme' }
      description { 'International Baccalaureate Programme' }
      association :vocabulary, :curriculum
    end

    trait :cambridge_igcse do
      slug { 'cambridge' }
      label { 'Cambridge IGCSE' }
      description { 'Cambridge International General Certificate of Secondary Education' }
      association :vocabulary, :curriculum
    end

    # Facility terms
    trait :library do
      slug { 'library' }
      label { 'Library' }
      description { 'School library and media center' }
      association :vocabulary, :facility
    end

    trait :swimming_pool do
      slug { 'swimming_pool' }
      label { 'Swimming Pool' }
      description { 'Swimming pool and aquatic facilities' }
      association :vocabulary, :facility
    end

    trait :gymnasium do
      slug { 'gymnasium' }
      label { 'Gymnasium' }
      description { 'Indoor sports and gymnasium facilities' }
      association :vocabulary, :facility
    end

    trait :science_lab do
      slug { 'science_lab' }
      label { 'Science Lab' }
      description { 'Science laboratory facilities' }
      association :vocabulary, :facility
    end

    # Language terms
    trait :english do
      slug { 'english' }
      label { 'English' }
      description { 'English language instruction' }
      association :vocabulary, :language
    end

    trait :thai do
      slug { 'thai' }
      label { 'Thai' }
      description { 'Thai language instruction' }
      association :vocabulary, :language
    end

    # Accreditation terms
    trait :wasc do
      slug { 'wasc' }
      label { 'WASC' }
      description { 'Western Association of Schools and Colleges accreditation' }
      association :vocabulary, :accreditation
    end

    trait :cis do
      slug { 'cis' }
      label { 'CIS' }
      description { 'Council of International Schools accreditation' }
      association :vocabulary, :accreditation
    end
  end
end
