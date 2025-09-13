FactoryBot.define do
  factory :youtube_video do
    association :place
    sequence(:video_id) { |n| "youtube_#{n}_#{SecureRandom.hex(4)}" }
    title { "School Tour Video" }
    description { "A comprehensive tour of our school facilities" }
    thumbnail_url { "https://img.youtube.com/vi/#{video_id}/hqdefault.jpg" }
    duration { "5:30" }
    view_count { 1500 }
    visible { true }
    sort_order { 0 }
    video_data { {} }

    trait :hidden do
      visible { false }
    end

    trait :with_high_views do
      view_count { 2_500_000 }
    end

    trait :with_metadata do
      video_data do
        {
          "published_at" => "2024-01-15",
          "channel_title" => "School Channel",
          "tags" => [ "education", "school", "tour" ]
        }
      end
    end
  end
end
