FactoryBot.define do
  factory :holding do
    association :portfolio
    symbol { "AAPL" }
    quantity { 10 }
    average_cost { 150.0 }
  end
end
