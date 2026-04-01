FactoryBot.define do
  factory :league_membership do
    association :user
    association :league
    joined_at { Time.current }
  end
end
