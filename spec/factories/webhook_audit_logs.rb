FactoryBot.define do
  factory :webhook_audit_log do
    webhook_type { %w[deletion deauthorization].sample }
    facebook_user_id { Faker::Number.number(digits: 10).to_s }
    payload { { "user_id" => facebook_user_id, "algorithm" => "HMAC-SHA256" } }
    status { "processed" }
    error_message { nil }
    processed_at { Time.current }
    user { nil }

    trait :deletion do
      webhook_type { "deletion" }
    end

    trait :deauthorization do
      webhook_type { "deauthorization" }
    end

    trait :processed do
      status { "processed" }
      error_message { nil }
    end

    trait :failed do
      status { "failed" }
      error_message { "Processing failed: timeout" }
    end

    trait :invalid do
      status { "invalid" }
      error_message { "Invalid signature" }
    end

    trait :with_user do
      association :user
    end

    trait :without_user do
      user { nil }
    end
  end
end
