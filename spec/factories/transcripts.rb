FactoryBot.define do
  factory :transcript do
    association :place
    sequence(:video_id) { |n| "video_#{n}_#{SecureRandom.hex(4)}" }
    video_title { "School Tour Video" }
    video_description { "A comprehensive tour of our facilities" }
    video_url { "https://www.youtube.com/watch?v=#{video_id}" }
    status { "completed" }
    full_transcript { "Welcome to our school. We offer excellent education programs." }
    language { "en" }
    duration_seconds { 300 }
    ai_enabled { true }
    processed_at { Time.current }
    
    trait :pending do
      status { "pending" }
      full_transcript { nil }
      processed_at { nil }
    end
    
    trait :processing do
      status { "processing" }
      full_transcript { nil }
    end
    
    trait :failed do
      status { "failed" }
      processing_error { "API error: Unable to fetch transcript" }
    end
    
    trait :no_transcript do
      status { "no_transcript" }
      processing_error { "No captions available" }
    end
    
    trait :with_cleaned do
      cleaned_transcript { "Welcome to our school. We offer excellent education programs." }
      transcript_cleaned_at { Time.current }
    end
    
    trait :with_embedding do
      # vector_embedding must be set via raw SQL after creation
      embedding_generated_at { Time.current }
      after(:create) do |transcript|
        ActiveRecord::Base.connection.execute("UPDATE transcripts SET vector_embedding = '[0.1, 0.2, 0.3, 0.4, 0.5]' WHERE id = #{transcript.id}")
      end
    end
  end
end