FactoryBot.define do
  factory :league do
    sequence(:name) { |n| "League #{n}" }
    description { "Test league" }
    starting_capital { 100_000 }
    start_date { Date.current }
    end_date { 1.month.from_now }
  end
end
