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
  stock_price = StockPrice.find_or_initialize_by(symbol: symbol)
  stock_price.price = price
  stock_price.save!
end

verified_at = Time.current

admin = User.find_or_initialize_by(email: "admin@mockfund.com")
admin.assign_attributes(
  username: "admin",
  role: "admin",
  password: "Admin123!",
  password_confirmation: "Admin123!",
  signup_verified_at: verified_at,
  skip_login_otp: true
)
admin.save!

users = Array.new(20) do |index|
  user = User.find_or_initialize_by(email: "user#{index + 1}@mockfund.com")
  user.assign_attributes(
    username: "user#{index + 1}",
    role: "user",
    password: "User123!",
    password_confirmation: "User123!",
    signup_verified_at: verified_at,
    skip_login_otp: true
  )
  user.save!
  user
end

now = Time.current.change(sec: 0)

league_spec = lambda do |name:, start_at:, end_at:, capital:, max_participants:|
  {
    name: name,
    start_date: start_at,
    end_date: end_at,
    starting_capital: capital,
    rules: { "max_participants" => max_participants }
  }
end

past_league_specs = (1..18).map do |index|
  start_at = now - ((index + 4) * 2).minutes
  league_spec.call(
    name: "Past Sprint League #{index}",
    start_at: start_at,
    end_at: start_at + 90.seconds,
    capital: 22_000 + (index * 1_100),
    max_participants: 14 + (index % 10)
  )
end

live_league_specs = (1..6).map do |index|
  start_at = now - (index * 40).seconds
  league_spec.call(
    name: "Live Sprint League #{index}",
    start_at: start_at,
    end_at: start_at + 4.minutes,
    capital: 35_000 + (index * 1_500),
    max_participants: 18 + (index % 8)
  )
end

upcoming_league_specs = (1..12).map do |index|
  start_at = now + (index * 40).seconds
  league_spec.call(
    name: "Upcoming Sprint League #{index}",
    start_at: start_at,
    end_at: start_at + 4.minutes,
    capital: 30_000 + (index * 1_800),
    max_participants: 16 + (index % 8)
  )
end

transition_probe_specs = [
  league_spec.call(
    name: "Transition Probe Start +20s",
    start_at: now + 20.seconds,
    end_at: now + 3.minutes + 20.seconds,
    capital: 100_000,
    max_participants: 25
  ),
  league_spec.call(
    name: "Transition Probe End +20s",
    start_at: now - 3.minutes,
    end_at: now + 20.seconds,
    capital: 95_000,
    max_participants: 25
  ),
  league_spec.call(
    name: "Transition Probe Warn15 +20s",
    start_at: now - 20.minutes,
    end_at: now + 15.minutes + 20.seconds,
    capital: 110_000,
    max_participants: 25
  )
]

final_check_batch_specs = []

4.times do |index|
  final_check_batch_specs << league_spec.call(
    name: "Final Check Start Batch #{index + 1}",
    start_at: now + 45.seconds,
    end_at: now + 5.minutes + 45.seconds,
    capital: 115_000 + (index * 2_000),
    max_participants: 30
  )
end

4.times do |index|
  final_check_batch_specs << league_spec.call(
    name: "Final Check End Batch #{index + 1}",
    start_at: now - 5.minutes,
    end_at: now + 45.seconds,
    capital: 118_000 + (index * 2_000),
    max_participants: 30
  )
end

4.times do |index|
  final_check_batch_specs << league_spec.call(
    name: "Final Check Warn Batch #{index + 1}",
    start_at: now - 25.minutes,
    end_at: now + 15.minutes + 20.seconds,
    capital: 122_000 + (index * 2_000),
    max_participants: 30
  )
end

league_specs = past_league_specs + live_league_specs + upcoming_league_specs + transition_probe_specs + final_check_batch_specs

seeded_description = "Sample league seeded for local development."

League.upsert_all(
  league_specs.map do |spec|
    {
      name: spec[:name],
      description: seeded_description,
      start_date: spec[:start_date],
      end_date: spec[:end_date],
      starting_capital: spec[:starting_capital],
      rules: spec[:rules],
      creator_id: admin.id,
      created_at: Time.current,
      updated_at: Time.current
    }
  end,
  unique_by: :index_leagues_on_name
)

leagues = League.where(name: league_specs.map { |spec| spec[:name] }).order(start_date: :asc, id: :asc).to_a

member_users = users.first(3)
probe_leagues = League.where(name: transition_probe_specs.map { |spec| spec[:name] }).to_a
final_check_leagues = League.where(name: final_check_batch_specs.map { |spec| spec[:name] }).to_a
registered_final_check_leagues = final_check_leagues.first(6)

probe_leagues.each do |league|
  member_users.each do |user|
    LeagueMembership.find_or_create_by!(user: user, league: league) do |membership|
      membership.joined_at = Time.current
    end

    user.portfolios.find_or_create_by!(league: league) do |portfolio|
      portfolio.cash_balance = league.starting_capital
    end
  end
end

# Register only user1 for a subset of final-check leagues, leaving others unregistered for notification filtering checks.
registered_final_check_leagues.each do |league|
  user = users.first
  LeagueMembership.find_or_create_by!(user: user, league: league) do |membership|
    membership.joined_at = Time.current
  end

  user.portfolios.find_or_create_by!(league: league) do |portfolio|
    portfolio.cash_balance = league.starting_capital
  end
end

Rails.cache.clear

puts "Seeded #{User.count} users, #{League.count} leagues, and #{StockPrice.count} stock prices."
puts "Running league: #{leagues.find(&:running_now?)&.name}"
puts "Transition probe leagues: #{transition_probe_specs.map { |spec| spec[:name] }.join(', ')}"
puts "Final-check batch leagues: #{final_check_batch_specs.size} (registered subset: #{registered_final_check_leagues.size})"
puts "Admin login: admin@mockfund.com / Admin123!"
