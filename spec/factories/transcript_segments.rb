FactoryBot.define do
  factory :transcript_segment do
    association :transcript
    sequence(:segment_index) { |n| n }
    text { "This is segment text about the school facilities and programs." }
    start_time { segment_index * 10.0 }
    end_time { (segment_index * 10.0) + 9.5 }
    speaker { nil }
    confidence { 0.95 }

    trait :with_speaker do
      speaker { "Narrator" }
    end

    trait :with_embedding do
      # vector_embedding must be set via raw SQL after creation
      embedding_generated_at { Time.current }
      after(:create) do |segment|
        vector = '[' + Array.new(1536, 0.1).join(',') + ']'
        ActiveRecord::Base.connection.execute("UPDATE transcript_segments SET vector_embedding = '#{vector}' WHERE id = #{segment.id}")
      end
    end

    trait :low_confidence do
      confidence { 0.65 }
    end
  end
end
