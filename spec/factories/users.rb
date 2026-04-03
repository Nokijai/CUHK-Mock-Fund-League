FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:username) { |n| "testuser#{n}" }
    password { "Test123!@#" }
    password_confirmation { "Test123!@#" }
    role { "participant" }
  end
end
