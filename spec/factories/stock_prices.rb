FactoryBot.define do
  factory :stock_price do
    sequence(:symbol) { |n| "X#{n}" }
    price { 150.25 }
  end
end
