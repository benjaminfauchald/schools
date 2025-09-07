FactoryBot.define do
  factory :place do
    name { Faker::Company.name }
    formatted_address { Faker::Address.full_address }
    vicinity { Faker::Address.street_address }
    lat { 13.7563 + rand(-0.1..0.1) } # Near Bangkok center
    lng { 100.5018 + rand(-0.1..0.1) } # Near Bangkok center

    # Ensure PostGIS geography is updated after creation
    after(:create) do |place|
      if place.lat.present? && place.lng.present?
        place.update_column(:location, "SRID=4326;POINT(#{place.lng} #{place.lat})")
      end
    end
    place_id { Faker::Alphanumeric.alphanumeric(number: 27) }
    business_status { 'OPERATIONAL' }
    rating { Faker::Number.decimal(l_digits: 1, r_digits: 1).clamp(1.0, 5.0) }
    user_ratings_total { Faker::Number.between(from: 1, to: 100) }

    trait :closed do
      business_status { 'CLOSED_TEMPORARILY' }
    end

    trait :high_rated do
      rating { Faker::Number.decimal(l_digits: 1, r_digits: 1).clamp(4.0, 5.0) }
      user_ratings_total { Faker::Number.between(from: 50, to: 500) }
    end

    trait :with_opening_hours do
      opening_hours {
        {
          "open_now" => true,
          "periods" => [
            {
              "close" => { "day" => 1, "time" => "1700" },
              "open" => { "day" => 1, "time" => "0800" }
            }
          ],
          "weekday_text" => [ "Monday: 8:00 AM – 5:00 PM" ]
        }
      }
    end
  end
end
