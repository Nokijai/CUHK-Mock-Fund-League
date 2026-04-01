# Clear all data in correct order (respecting foreign key constraints)
Trade.delete_all
Holding.delete_all
Portfolio.delete_all
LeagueMembership.delete_all
League.delete_all
User.delete_all

# Reset ID sequences to start from 1
ActiveRecord::Base.connection.reset_pk_sequence!('users')
ActiveRecord::Base.connection.reset_pk_sequence!('leagues')
ActiveRecord::Base.connection.reset_pk_sequence!('portfolios')
ActiveRecord::Base.connection.reset_pk_sequence!('holdings')
ActiveRecord::Base.connection.reset_pk_sequence!('trades')

# Create admin user
admin = User.create!(
  email: "admin@mockfund.com",
  name: "Admin User",
  role: "admin",
  password: "Admin123!",
  password_confirmation: "Admin123!"
)

# Create regular users
users = []
50.times do |i|
  users << User.create!(
    email: "user#{i + 1}@mockfund.com",
    name: "User #{i + 1}",
    role: "user",
    password: "User123!",
    password_confirmation: "User123!"
  )
end

puts "✓ Created 1 admin and 50 regular users"

# Create sample leagues
league_names = [
  "Spring Trading Challenge 2026",
  "Tech Stocks Competition",
  "Value Investing League",
  "Crypto & Blockchain Fund",
  "ESG Sustainable Portfolio",
  "Blue Chip Champions",
  "Growth Stocks Arena",
  "Dividend Income League",
  "International Markets",
  "Small Cap Discovery",
  "Energy Sector Focus",
  "Healthcare Innovation",
  "Financial Services League",
  "Consumer Brands Battle",
  "Real Estate Investment",
  "Emerging Markets Challenge",
  "AI & Technology Future",
  "Retail Trading Masters",
  "Banking Sector League",
  "Manufacturing Excellence"
]

leagues = []
20.times do |i|
  leagues << League.create!(
    name: league_names[i],
    start_date: Date.today + rand(1..15).days,
    end_date: Date.today + rand(60..120).days,
    starting_capital: [10000, 25000, 50000, 100000].sample
  )
end

puts "✓ Created 20 sample leagues"

# Add some users to some leagues (create portfolios and league memberships)
leagues.each do |league|
  users.sample(rand(3..8)).each do |user|
    next if LeagueMembership.exists?(league: league, user: user)
    
    LeagueMembership.create!(
      league: league,
      user: user
    )
    
    Portfolio.create!(
      league: league,
      user: user,
      cash_balance: league.starting_capital
    ) unless Portfolio.exists?(league: league, user: user)
  end
end

puts "✓ Added users to leagues with portfolios"
puts "━" * 50
puts "Admin Login:"
puts "  Email: admin@mockfund.com"
puts "  Password: Admin123!"
puts ""
puts "Regular Users:"
puts "  Email: user1@mockfund.com - user50@mockfund.com"
puts "  Password: User123!"
puts "━" * 50
