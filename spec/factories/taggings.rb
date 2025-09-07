FactoryBot.define do
  factory :tagging do
    association :term
    association :taggable, factory: :school
    context { term&.vocabulary&.code || 'curriculum' }
    notes { Faker::Lorem.sentence }
    valid_from { nil }
    valid_to { nil }

    trait :with_school do
      association :taggable, factory: :school
    end

    trait :with_place do
      association :taggable, factory: :place
    end

    trait :expired do
      valid_from { 2.years.ago }
      valid_to { 1.year.ago }
    end

    trait :current do
      valid_from { 1.year.ago }
      valid_to { 1.year.from_now }
    end

    trait :future do
      valid_from { 1.month.from_now }
      valid_to { 1.year.from_now }
    end

    # Context-specific taggings
    trait :curriculum_context do
      context { 'curriculum' }
      association :term, :ib_programme
    end

    trait :facility_context do
      context { 'facility' }
      association :term, :library
    end

    trait :language_context do
      context { 'language' }
      association :term, :english
    end

    trait :accreditation_context do
      context { 'accreditation' }
      association :term, :wasc
    end

    # Override context based on term if provided
    before(:create) do |tagging|
      if tagging.term&.vocabulary&.code
        tagging.context = tagging.term.vocabulary.code
      end
    end
  end
end
