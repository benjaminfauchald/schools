FactoryBot.define do
  factory :event do
    title { Faker::Lorem.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph }
    starts_at { 1.week.from_now }
    url { Faker::Internet.url }
    association :place

    after(:build) do |event|
      event.ends_at ||= event.starts_at + 2.hours
    end

    trait :past do
      starts_at { 1.week.ago }
      ends_at { 1.week.ago + 2.hours }
    end

    trait :happening_now do
      starts_at { 1.hour.ago }
      ends_at { 1.hour.from_now }
    end

    trait :today do
      starts_at { Time.current.beginning_of_day + 14.hours }
      ends_at { Time.current.beginning_of_day + 16.hours }
    end

    trait :no_end_time do
      ends_at { nil }
    end

    trait :multi_day do
      starts_at { 1.week.from_now }
      ends_at { 1.week.from_now + 2.days }
    end

    trait :all_day do
      starts_at { 1.week.from_now.beginning_of_day }
      ends_at { 1.week.from_now.end_of_day }
    end

    trait :with_url do
      url { 'https://example.com/event' }
    end

    trait :without_url do
      url { nil }
    end
  end
end
