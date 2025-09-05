FactoryBot.define do
  factory :school do
    name { Faker::Educator.secondary_school }
    slug { name.parameterize }
    about { Faker::Lorem.paragraph(sentence_count: 3) }
    phone { Faker::PhoneNumber.phone_number }
    email { Faker::Internet.email }
    website_url { Faker::Internet.url }
    lat { Faker::Address.latitude }
    lng { Faker::Address.longitude }
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