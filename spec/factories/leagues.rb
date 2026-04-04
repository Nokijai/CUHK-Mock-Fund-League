FactoryBot.define do
  factory :league do
    sequence(:name) { |n| "League #{n}" }
    description { "Test league" }
    starting_capital { 100_000 }
    # League creation now enforces future start dates.
    start_date { 1.day.from_now }
    end_date { 1.month.from_now }
  end
end
