FactoryBot.define do
  factory :school_claim do
    association :user
    association :school
    evidence_url { Faker::Internet.url }
    notes { Faker::Lorem.paragraph }
    status { 'pending' }
    
    trait :approved do
      status { 'approved' }
    end
    
    trait :rejected do
      status { 'rejected' }
      admin_notes { Faker::Lorem.sentence }
    end
    
    trait :with_admin_notes do
      admin_notes { Faker::Lorem.paragraph }
    end
  end
end