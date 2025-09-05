FactoryBot.define do
  factory :media_item do
    association :place
    kind { 'photo' }
    url { Faker::Internet.url(host: 'example.com', path: '/image.jpg') }
    alt_text { Faker::Lorem.sentence }
    source { 'admin_upload' }
    sort_order { 1 }
    
    trait :logo do
      kind { 'logo' }
      url { Faker::Internet.url(host: 'example.com', path: '/logo.png') }
    end
    
    trait :brochure do
      kind { 'brochure' }
      url { Faker::Internet.url(host: 'example.com', path: '/brochure.pdf') }
    end
    
    trait :fee_schedule do
      kind { 'fee_schedule_pdf' }
      url { Faker::Internet.url(host: 'example.com', path: '/fees.pdf') }
    end
    
    trait :video do
      kind { 'video' }
      url { Faker::Internet.url(host: 'example.com', path: '/video.mp4') }
    end
    
    trait :virtual_tour do
      kind { 'virtual_tour' }
      url { Faker::Internet.url(host: 'example.com', path: '/tour') }
    end
    
    trait :google_places do
      source { 'google_places' }
    end
    
    trait :school_upload do
      source { 'school_upload' }
    end
  end
end