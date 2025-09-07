FactoryBot.define do
  factory :page do
    school
    sequence(:title) { |n| "Page #{n}" }
    content { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    status { 'published' }
    page_type { 'general' }
    slug { title.parameterize if title.present? }
    meta_description { Faker::Lorem.sentence(word_count: 20) }
    sort_order { 0 }

    trait :draft do
      status { 'draft' }
    end

    trait :about_us do
      title { 'About Us' }
      page_type { 'about_us' }
      content { "Learn more about our school's mission, vision, and values. #{Faker::Lorem.paragraphs(number: 2).join('\n\n')}" }
    end

    trait :academics do
      title { 'Academic Programs' }
      page_type { 'academics' }
      content { "Discover our comprehensive academic programs. #{Faker::Lorem.paragraphs(number: 2).join('\n\n')}" }
    end

    trait :admissions do
      title { 'Admissions' }
      page_type { 'admissions' }
      content { "Information about our admissions process. #{Faker::Lorem.paragraphs(number: 2).join('\n\n')}" }
    end

    after(:build) do |page|
      if page.title.present? && page.slug.blank?
        page.slug = page.title.parameterize
      end
    end
  end
end
