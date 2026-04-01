# Clear all data in dependency order.
Trade.delete_all
Holding.delete_all
Portfolio.delete_all
LeagueMembership.delete_all
League.delete_all
User.delete_all
StockCandle.delete_all
StockPrice.delete_all

# Reset primary key sequences for deterministic seed IDs.
%w[users leagues portfolios holdings trades stock_prices stock_candles].each do |table_name|
  ActiveRecord::Base.connection.reset_pk_sequence!(table_name)
end


admin = User.create!(
  email: "admin@mockfund.com",
  name: "Admin User",
  role: "admin",
  password: "Admin123!",
  password_confirmation: "Admin123!"
)

users = Array.new(20) do |index|
  User.create!(
    email: "user#{index + 1}@mockfund.com",
    name: "User #{index + 1}",
    role: "user",
    password: "User123!",
    password_confirmation: "User123!"
  )
end

# League dates must be in the future to satisfy model validations.
league_names = [
  "Spring Trading Challenge 2026",
  "Tech Stocks Competition",
  "Value Investing League",
  "Blue Chip Champions",
  "Growth Stocks Arena",
  "International Markets"
]

leagues = league_names.each_with_index.map do |name, index|
  start_at = Time.current + (index + 2).days
  League.create!(
    name:,
    description: "Sample league seeded for local development.",
    start_date: start_at,
    end_date: start_at + 90.days,
    starting_capital: [10_000, 25_000, 50_000, 100_000].sample,
    rules: { "max_position_pct" => 25 }
  )
end

leagues.each do |league|
  members = users.sample(rand(4..10))
  members << admin if rand < 0.5

  members.uniq.each do |member|
    LeagueMembership.create!(league:, user: member, joined_at: Time.current)
    Portfolio.create!(league:, user: member, cash_balance: league.starting_capital)
  end
end

puts "Seeded #{User.count} users (including admin), #{League.count} leagues."
puts "Admin login: admin@mockfund.com / Admin123!"
