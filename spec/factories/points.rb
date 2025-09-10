FactoryBot.define do
  factory :point do
    sequence(:osm_id) { |n| n }
    name { "Test Point #{osm_id}" }
    amenity { "school" }
    lat { 13.7563 }
    lon { 100.5018 }
    # PostGIS geometry field - using factory to build the geometry
    way { RGeo::Geographic.spherical_factory(srid: 4326).point(lon, lat) }

    trait :school do
      amenity { "school" }
      school_type { "international" }
    end

    trait :with_tags do
      tags { { "website" => "http://example.com", "phone" => "+66 2 123 4567" } }
    end

    trait :with_operator do
      operator { "Test Operator" }
      operator_type { "private" }
    end
  end
end
