# Clear all data in correct order (respecting foreign key constraints)
Trade.delete_all
Holding.delete_all
Portfolio.delete_all
LeagueMembership.delete_all
League.delete_all
User.delete_all

# Create admin user
admin = User.create!(
  email: "admin@mockfund.com",
  name: "Admin",
  role: "admin",
  password: "Admin123!",
  password_confirmation: "Admin123!"
)

puts "✓ Admin user created successfully!"
puts "Email: admin@mockfund.com"
puts "Password: Admin123!"
