FactoryBot.define do
  factory :trade do
    association :portfolio
    symbol { "AAPL" }
    trade_type { "buy" }
    quantity { 10 }
    price { 150.0 }
    executed_at { Time.current }
  end
end
