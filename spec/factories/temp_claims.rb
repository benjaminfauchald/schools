FactoryBot.define do
  factory :temp_claim do
    association :school
    email { Faker::Internet.email }
    token { SecureRandom.urlsafe_base64(32) }
    status { "pending_registration" }
    ip_address { Faker::Internet.ip_v4_address }
    expires_at { 48.hours.from_now }
    evidence_url { Faker::Internet.url }
    notes { Faker::Lorem.paragraph }

    trait :registered do
      status { "registered" }
    end

    trait :expired do
      status { "expired" }
      expires_at { 1.hour.ago }
    end

    trait :pending do
      status { "pending_registration" }
    end

    trait :about_to_expire do
      expires_at { 1.hour.from_now }
    end
  end
end
