FactoryBot.define do
  factory :ai_conversation do
    association :school
    association :user
    title { "Chat #{Faker::Date.backward(days: 7).strftime('%b %d, %Y')}" }
    status { "active" }
    last_message_at { nil }

    trait :with_messages do
      after(:create) do |conversation|
        create(:ai_message, :user_message, ai_conversation: conversation)
        create(:ai_message, :assistant_message, ai_conversation: conversation)
      end
    end

    trait :archived do
      status { "archived" }
    end

    trait :recent do
      created_at { 1.hour.ago }
      last_message_at { 5.minutes.ago }
    end
  end
end
