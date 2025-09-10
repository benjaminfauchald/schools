FactoryBot.define do
  factory :magic_link_token do
    association :user
    purpose { 'dashboard_access' }
    expires_at { 48.hours.from_now }
    token { SecureRandom.urlsafe_base64(32) }

    trait :expired do
      expires_at { 1.hour.ago }
    end

    trait :used do
      used_at { 1.hour.ago }
    end

    trait :password_reset do
      purpose { 'password_reset' }
    end
  end
end
