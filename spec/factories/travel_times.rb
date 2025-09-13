FactoryBot.define do
  factory :travel_time do
    association :place
    sequence(:origin_hash) { |n| "hash_#{n}_#{SecureRandom.hex(8)}" }
    minutes { 15 }
    mode { "driving" }
    computed_at { Time.current }

    trait :walking do
      mode { "walking" }
      minutes { 30 }
    end

    trait :transit do
      mode { "transit" }
      minutes { 20 }
    end

    trait :close do
      minutes { 5 }
    end

    trait :far do
      minutes { 60 }
    end

    trait :stale do
      computed_at { 25.hours.ago }
    end
  end
end
