FactoryBot.define do
  factory :school_claim do
    association :user
    association :school
    evidence_url { Faker::Internet.url }
    notes { Faker::Lorem.paragraph }
    ip_address { Faker::Internet.ip_v4_address }
    status { 'pending' }
    
    trait :approved do
      status { 'approved' }
      approved_at { Time.current }
    end
    
    trait :rejected do
      status { 'rejected' }
      rejection_reason { Faker::Lorem.sentence }
    end
    
    trait :with_admin_notes do
      admin_notes { Faker::Lorem.paragraph }
    end
  end
end