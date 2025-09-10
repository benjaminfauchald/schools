FactoryBot.define do
  factory :page do
    association :school
    title { Faker::Lorem.sentence(word_count: 3) }
    content { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    slug { title&.parameterize }
    page_type { Page::PAGE_TYPES.keys.sample }
    status { "draft" }
    meta_description { nil }
    sort_order { nil }
    published_at { nil }

    trait :published do
      status { "published" }
      published_at { 1.day.ago }
    end

    trait :archived do
      status { "archived" }
    end

    trait :with_meta do
      meta_description { Faker::Lorem.sentence(word_count: 10) }
    end

    trait :about_page do
      page_type { "about_us" }
      title { "About Our School" }
    end

    trait :blog_post do
      page_type { "blog" }
      title { Faker::Lorem.sentence(word_count: 5) }
    end
  end
end
