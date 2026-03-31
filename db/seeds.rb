require "bcrypt"

StockPrice.delete_all
Trade.delete_all
Holding.delete_all
Portfolio.delete_all
LeagueMembership.delete_all
League.delete_all
User.delete_all

def digest(pw)
  BCrypt::Password.create(pw)
end

[
  [ "AAPL", 189.23 ],
  [ "MSFT", 378.50 ],
  [ "GOOGL", 141.20 ],
  [ "NVDA", 875.10 ],
  [ "0700", 328.00 ],
  [ "META", 485.30 ]
].each do |sym, pr|
  StockPrice.create!(symbol: sym, price: pr, updated_at: Time.current)
end

league = League.create!(
  name: "Spring 2026 Competition",
  description: "CUHK Mock-Fund virtual trading league. Virtual capital only.",
  starting_capital: 100_000,
  start_date: Date.current - 30,
  end_date: Date.current + 90,
  rules: { "max_position_pct" => 25 }
)

participants = [
  { name: "Alex Chen", cash: 900, holdings: { "NVDA" => [ 135, 800.0 ] } },
  { name: "Jordan Lee", cash: 200, holdings: { "MSFT" => [ 200, 360.0 ], "GOOGL" => [ 274, 135.0 ] } },
  { name: "Demo Trader", cash: 61_331.50, holdings: { "0700" => [ 100, 312.50 ], "AAPL" => [ 50, 178.20 ] } },
  { name: "Sam Wong", cash: 10_000, holdings: { "META" => [ 60, 470.0 ], "0700" => [ 80, 315.0 ] } },
  { name: "Taylor Ho", cash: 30_000, holdings: { "GOOGL" => [ 450, 135.0 ] } },
  { name: "Riley Au", cash: 55_000, holdings: { "AAPL" => [ 100, 182.0 ] } },
  { name: "Casey Lam", cash: 40_000, holdings: { "MSFT" => [ 50, 365.0 ], "NVDA" => [ 10, 820.0 ] } },
  { name: "Morgan Yip", cash: 85_000, holdings: {} },
  { name: "Jamie Ng", cash: 25_000, holdings: { "0700" => [ 170, 308.0 ] } },
  { name: "Quinn Lau", cash: 35_000, holdings: { "NVDA" => [ 50, 820.0 ] } },
  { name: "Blake Cheung", cash: 70_000, holdings: { "AAPL" => [ 30, 184.0 ] } },
  { name: "Sky Mak", cash: 58_000, holdings: { "MSFT" => [ 40, 372.0 ] } }
]

participants.each_with_index do |row, i|
  u = User.create!(
    email: "participant#{i + 1}@demo.local",
    name: row[:name],
    role: "participant",
    password_digest: digest("password")
  )
  LeagueMembership.create!(user: u, league: league, joined_at: Time.current - rand(20).days)
  p = Portfolio.create!(user: u, league: league, cash_balance: row[:cash], total_value: 0)
  row[:holdings].each do |sym, (qty, avg)|
    Holding.create!(portfolio: p, symbol: sym, quantity: qty, average_cost: avg)
  end
end

admin = User.create!(
  email: "admin@demo.local",
  name: "League Admin",
  role: "admin",
  password_digest: digest("password")
)
LeagueMembership.create!(user: admin, league: league, joined_at: Time.current)

demo_user = User.find_by(name: "Demo Trader")
demo_p = demo_user.portfolios.first
[
  [ "0700", "buy", 100, 312.50 ],
  [ "AAPL", "buy", 50, 178.20 ],
  [ "0700", "buy", 20, 305.00 ]
].each do |sym, ttype, qty, pr|
  Trade.create!(
    portfolio: demo_p,
    symbol: sym,
    trade_type: ttype,
    quantity: qty,
    price: pr,
    executed_at: Time.current - rand(1..10).days
  )
end

puts "Seeded league=#{league.name}, users=#{User.count}. Demo login: participant3@demo.local / password"
