FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Test User" }
    # Keep factory aligned with role validation in User::ROLES.
    role { "user" }
    password { "Password1!" }
    password_confirmation { "Password1!" }
  end
end
