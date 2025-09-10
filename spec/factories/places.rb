FactoryBot.define do
  factory :place do
    place_id { "ChIJ#{SecureRandom.hex(8)}" }
    name { Faker::Company.name }
    formatted_address { Faker::Address.full_address }
    lat { Faker::Address.latitude }
    lng { Faker::Address.longitude }
    types { [ 'establishment', 'point_of_interest' ] }
    rating { [ nil, 3.5, 4.0, 4.5, 5.0 ].sample }
    user_ratings_total { rating ? Faker::Number.between(from: 10, to: 500) : nil }
    formatted_phone_number { Faker::PhoneNumber.phone_number }
    website { Faker::Internet.url }
    opening_hours { { "open_now" => [ true, false ].sample } }
    photos { [] }
    reviews { [] }
    api_status { "OK" }
    last_fetched_at { Time.current }
    raw_api_response { {} }

    trait :school do
      name { "#{Faker::Educator.campus} School" }
      types { [ 'school', 'establishment', 'point_of_interest' ] }
    end

    trait :with_point do
      association :point
    end

    trait :highly_rated do
      rating { [ 4.0, 4.5, 5.0 ].sample }
      user_ratings_total { Faker::Number.between(from: 50, to: 1000) }
    end

    trait :needs_refresh do
      last_fetched_at { 31.days.ago }
    end

    trait :never_fetched do
      last_fetched_at { nil }
    end

    trait :with_website do
      website { Faker::Internet.url }
      website_crawled_at { nil }
    end

    trait :crawled do
      website { Faker::Internet.url }
      website_crawled_at { 1.day.ago }
      website_crawling_status { 'completed' }
      website_structured_data { { "school_type" => "international" } }
    end

    trait :with_photos do
      photos do
        3.times.map do
          {
            "photo_reference" => SecureRandom.hex(20),
            "width" => 1024,
            "height" => 768
          }
        end
      end
    end

    trait :with_reviews do
      reviews do
        3.times.map do
          {
            "author_name" => Faker::Name.name,
            "rating" => [ 3, 4, 5 ].sample,
            "text" => Faker::Lorem.paragraph,
            "time" => Faker::Time.backward(days: 30).to_i
          }
        end
      end
    end

    trait :api_error do
      api_status { "ZERO_RESULTS" }
    end
  end
end
