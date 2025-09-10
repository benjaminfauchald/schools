FactoryBot.define do
  factory :school_inquiry do
    association :school
    user { nil }  # Make user optional by default
    name { Faker::Name.name }
    email { Faker::Internet.email }
    phone { Faker::PhoneNumber.phone_number }
    message { Faker::Lorem.paragraph(sentence_count: 3) }
    children_count { rand(1..4) }
    ip_address { Faker::Internet.ip_v4_address }

    trait :without_phone do
      phone { nil }
    end

    trait :large_family do
      children_count { rand(5..10) }
    end

    trait :long_message do
      message { Faker::Lorem.paragraph(sentence_count: 10) }
    end

    trait :minimal do
      name { 'Test User' }
      email { 'test@example.com' }
      message { 'I am interested in your school.' }
      children_count { 1 }
    end

    trait :with_special_characters do
      name { 'José María García-López' }
      email { 'jose.garcia@dominio.es' }
      message { 'Hola! 你好! こんにちは! Interested in bilingual education 🎓' }
    end
  end
end
