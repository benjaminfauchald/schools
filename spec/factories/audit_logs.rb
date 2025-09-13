FactoryBot.define do
  factory :audit_log do
    association :auditable, factory: :school
    action { "update" }
    user_id { nil }
    changed_fields { { "name" => [ "Old Name", "New Name" ] } }

    trait :create_action do
      action { "create" }
      changed_fields { {} }
    end

    trait :delete_action do
      action { "delete" }
      changed_fields { {} }
    end

    trait :approve_action do
      action { "approve" }
      changed_fields { { "status" => [ "pending", "approved" ] } }
    end

    trait :with_user do
      user_id { 1 }
    end

    trait :for_place do
      association :auditable, factory: :place
    end

    trait :for_school do
      association :auditable, factory: :school
    end
  end
end
