FactoryBot.define do
  factory :school do
    sequence(:name) { |n| "#{Faker::Educator.secondary_school} #{n}" }
    slug { "#{name.parameterize}-#{SecureRandom.hex(3)}" }
    about { Faker::Lorem.paragraph(sentence_count: 3) }
    phone { Faker::PhoneNumber.phone_number }
    email { Faker::Internet.email }
    website_url { Faker::Internet.url }
    lat { 13.7563 + rand(-0.1..0.1) } # Near Bangkok center
    lng { 100.5018 + rand(-0.1..0.1) } # Near Bangkok center
    
    # Ensure PostGIS geometry is updated after creation
    after(:create) do |school|
      school.send(:update_geography!) if school.lat.present? && school.lng.present?
    end
    status { 'published' }
    founded_year { Faker::Number.between(from: 1950, to: Date.current.year) }
    ownership { %w[nonprofit private foundation other].sample }
    
    association :place
    
    trait :draft do
      status { 'draft' }
    end
    
    trait :with_media do
      after(:create) do |school|
        create_list(:media_item, 3, place: school.place)
      end
    end
    
    trait :with_claims do
      after(:create) do |school|
        create_list(:school_claim, 2, school: school)
      end
    end
    
    trait :international do
      ownership { 'private' }
      name { "#{Faker::Address.city} International School" }
    end
    
    trait :boarding do
      boarding { true }
    end
    
    trait :with_bus do
      school_bus { true }
    end
  end
end