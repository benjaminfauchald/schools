FactoryBot.define do
  factory :ai_message do
    association :ai_conversation
    role { "user" }
    content { Faker::Lorem.paragraph }
    message_type { "text" }
    source_references { [] }
    metadata { {} }

    trait :user_message do
      role { "user" }
      content { "Tell me about the school facilities" }
    end

    trait :assistant_message do
      role { "assistant" }
      content { "The school has excellent facilities including a modern library and sports complex." }
      source_references do
        [
          { "type" => "school_data", "field_name" => "facilities", "description" => "School facilities information" }
        ]
      end
    end

    trait :suggested_question do
      role { "assistant" }
      message_type { "suggested_question" }
      content { "What curriculum does your school offer?" }
      metadata { { "category" => "academics", "priority" => "high" } }
    end

    trait :data_analysis do
      role { "assistant" }
      message_type { "data_analysis" }
      content { "Your school profile is 75% complete. Consider adding more details about your facilities." }
      metadata { { "completeness_score" => 75, "missing_fields" => [ "facilities" ] } }
    end

    trait :with_sources do
      source_references do
        [
          { "type" => "document", "title" => "School Brochure", "url" => "/documents/brochure.pdf" },
          { "type" => "transcript", "video_title" => "School Tour", "youtube_url" => "https://youtube.com/watch?v=abc123" }
        ]
      end
    end
  end
end
