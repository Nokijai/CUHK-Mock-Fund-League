FactoryBot.define do
  factory :portfolio do
    association :user
    association :league
    cash_balance { 100_000 }
    total_value { 100_000 }
  end
end
