FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    password { 'password123' }
    role { 'school_owner' }
    confirmed_at { Time.current }

    trait :admin do
      role { 'admin' }
    end

    trait :school_owner do
      role { 'school_owner' }
    end

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :facebook_user do
      provider { 'facebook' }
      uid { Faker::Number.unique.number(digits: 10).to_s }
      facebook_name { Faker::Name.name }
      facebook_profile_picture_url { Faker::Internet.url(host: 'graph.facebook.com') }
    end

    trait :with_school_claims do
      after(:create) do |user|
        create_list(:school_claim, 2, user: user)
      end
    end
  end
end
