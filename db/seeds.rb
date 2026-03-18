# Create sample data for development

# Users
admin = User.create!(email: "admin@example.com", name: "Admin", password_digest: BCrypt::Password.create("password123"), role: "admin")
user1 = User.create!(email: "alice@example.com", name: "Alice Wong", password_digest: BCrypt::Password.create("password123"), role: "user")
user2 = User.create!(email: "bob@example.com", name: "Bob Chan", password_digest: BCrypt::Password.create("password123"), role: "user")
user3 = User.create!(email: "charlie@example.com", name: "Charlie Lee", password_digest: BCrypt::Password.create("password123"), role: "user")

# Leagues
league1 = League.create!(
  name: "CUHK Spring 2026 League",
  description: "Mock trading competition for CUHK students",
  start_date: Date.today,
  end_date: Date.today + 90.days,
  starting_capital: 100000.00
)

league2 = League.create!(
  name: "Beginner League",
  description: "Practice league for new traders",
  start_date: Date.today,
  end_date: Date.today + 30.days,
  starting_capital: 50000.00
)

# League Memberships
[user1, user2, user3].each do |user|
  LeagueMembership.create!(user: user, league: league1, joined_at: Time.current)
end

[user1, user2].each do |user|
  LeagueMembership.create!(user: user, league: league2, joined_at: Time.current)
end

# Portfolios
portfolio1 = Portfolio.create!(user: user1, league: league1, cash_balance: 95000.00, total_value: 100500.00)
portfolio2 = Portfolio.create!(user: user2, league: league1, cash_balance: 80000.00, total_value: 102000.00)
portfolio3 = Portfolio.create!(user: user3, league: league1, cash_balance: 100000.00, total_value: 100000.00)

# Stock Prices
stocks = [
  { symbol: "AAPL", price: 178.50 },
  { symbol: "GOOGL", price: 141.25 },
  { symbol: "MSFT", price: 415.80 },
  { symbol: "TSLA", price: 175.30 },
  { symbol: "AMZN", price: 178.90 },
  { symbol: "NVDA", price: 875.50 },
  { symbol: "META", price: 505.75 },
  { symbol: "0700.HK", price: 298.40 },
  { symbol: "9988.HK", price: 72.85 },
  { symbol: "1299.HK", price: 45.20 }
]

stocks.each do |stock|
  StockPrice.create!(symbol: stock[:symbol], price: stock[:price])
end

# Holdings
Holding.create!(portfolio: portfolio1, symbol: "AAPL", quantity: 20, average_cost: 175.00)
Holding.create!(portfolio: portfolio1, symbol: "GOOGL", quantity: 15, average_cost: 140.00)
Holding.create!(portfolio: portfolio2, symbol: "MSFT", quantity: 30, average_cost: 410.00)
Holding.create!(portfolio: portfolio2, symbol: "NVDA", quantity: 10, average_cost: 850.00)

# Trades
Trade.create!(portfolio: portfolio1, symbol: "AAPL", trade_type: "buy", quantity: 20, price: 175.00, executed_at: 2.days.ago)
Trade.create!(portfolio: portfolio1, symbol: "GOOGL", trade_type: "buy", quantity: 15, price: 140.00, executed_at: 1.day.ago)
Trade.create!(portfolio: portfolio2, symbol: "MSFT", trade_type: "buy", quantity: 30, price: 410.00, executed_at: 3.days.ago)
Trade.create!(portfolio: portfolio2, symbol: "NVDA", trade_type: "buy", quantity: 10, price: 850.00, executed_at: 1.day.ago)

puts "Seed data created successfully!"
puts "Users: #{User.count}"
puts "Leagues: #{League.count}"
puts "Portfolios: #{Portfolio.count}"
puts "Stock Prices: #{StockPrice.count}"
puts "Holdings: #{Holding.count}"
puts "Trades: #{Trade.count}"
