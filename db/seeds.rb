# Clear all data in correct order (respecting foreign key constraints)
Trade.delete_all
Holding.delete_all
Portfolio.delete_all
LeagueMembership.delete_all
League.delete_all
User.delete_all
StockPrice.delete_all

puts "== Seeding stock prices =="
stock_prices = {
  "AAPL" => 188.75,
  "NVDA" => 875.20,
  "MSFT" => 421.30,
  "GOOGL" => 168.10,
  "META" => 515.40,
  "0700" => 402.75,
  "AMZN" => 181.10,
  "TSLA" => 243.80
}

stock_prices.each do |symbol, price|
  StockPrice.create!(symbol: symbol, price: price)
end

puts "== Seeding users and league =="
admin = User.create!(
  email: "admin@mockfund.com",
  name: "Admin",
  role: "admin",
  password: "Admin123!",
  password_confirmation: "Admin123!"
)

league = League.create!(
  name: "CUHK Spring League",
  description: "Seeded league for dashboard testing",
  starting_capital: 100_000,
  start_date: Date.current - 30,
  end_date: Date.current + 30
)

demo = User.create!(
  email: "demo@mockfund.com",
  name: "Demo Trader",
  role: "participant",
  password: "Demo123!",
  password_confirmation: "Demo123!"
)

rival = User.create!(
  email: "rival@mockfund.com",
  name: "Rival Trader",
  role: "participant",
  password: "Rival123!",
  password_confirmation: "Rival123!"
)

momentum = User.create!(
  email: "momentum@mockfund.com",
  name: "Momentum Trader",
  role: "participant",
  password: "Momentum123!",
  password_confirmation: "Momentum123!"
)

[ demo, rival, momentum ].each do |user|
  LeagueMembership.create!(league: league, user: user, joined_at: 20.days.ago)
end

def create_portfolio_bundle(user:, league:, cash_balance:, total_value:)
  Portfolio.create!(user: user, league: league, cash_balance: cash_balance, total_value: total_value)
end

puts "== Seeding portfolios =="
demo_portfolio = create_portfolio_bundle(user: demo, league: league, cash_balance: 22_000, total_value: 121_699.50)
rival_portfolio = create_portfolio_bundle(user: rival, league: league, cash_balance: 30_150, total_value: 84_908.50)
momentum_portfolio = create_portfolio_bundle(user: momentum, league: league, cash_balance: 38_750, total_value: 110_427.50)

puts "== Seeding holdings and trades =="
Holding.create!(portfolio: demo_portfolio, symbol: "AAPL", quantity: 250, average_cost: 156.0)
Holding.create!(portfolio: demo_portfolio, symbol: "NVDA", quantity: 60, average_cost: 650.0)

Trade.create!(portfolio: demo_portfolio, symbol: "AAPL", trade_type: "buy", quantity: 150, price: 150.0, executed_at: 12.days.ago)
Trade.create!(portfolio: demo_portfolio, symbol: "AAPL", trade_type: "buy", quantity: 100, price: 165.0, executed_at: 8.days.ago)
Trade.create!(portfolio: demo_portfolio, symbol: "NVDA", trade_type: "buy", quantity: 60, price: 650.0, executed_at: 2.days.ago)

Holding.create!(portfolio: rival_portfolio, symbol: "MSFT", quantity: 120, average_cost: 280.0)
Holding.create!(portfolio: rival_portfolio, symbol: "GOOGL", quantity: 25, average_cost: 1450.0)

Trade.create!(portfolio: rival_portfolio, symbol: "MSFT", trade_type: "buy", quantity: 120, price: 280.0, executed_at: 11.days.ago)
Trade.create!(portfolio: rival_portfolio, symbol: "GOOGL", trade_type: "buy", quantity: 25, price: 1450.0, executed_at: 5.days.ago)

Holding.create!(portfolio: momentum_portfolio, symbol: "META", quantity: 100, average_cost: 430.0)
Holding.create!(portfolio: momentum_portfolio, symbol: "0700", quantity: 50, average_cost: 365.0)

Trade.create!(portfolio: momentum_portfolio, symbol: "META", trade_type: "buy", quantity: 100, price: 430.0, executed_at: 13.days.ago)
Trade.create!(portfolio: momentum_portfolio, symbol: "0700", trade_type: "buy", quantity: 50, price: 365.0, executed_at: 1.day.ago)

puts "✓ Seed data created"
puts "Admin login: admin@mockfund.com / Admin123!"
puts "Demo login: demo@mockfund.com / Demo123!"
