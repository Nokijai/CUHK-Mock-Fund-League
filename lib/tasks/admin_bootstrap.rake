# frozen_string_literal: true

# One-time admin provisioning for production (or any env): never commit real credentials.
# Usage (local / Heroku one-off):
#   ADMIN_EMAIL=you@example.com ADMIN_PASSWORD='YourStrongPass1!' bin/rails admin:bootstrap
#
# If the password does not satisfy `User` complexity rules, either pick a compliant password
# or set ADMIN_BOOTSTRAP_RELAX_PASSWORD_POLICY=1 once, then rotate the password after login.
namespace :admin do
  desc "Create a single verified admin from ADMIN_EMAIL + ADMIN_PASSWORD (ENV). Does not load db/seeds.rb."
  task bootstrap: :environment do
    email = ENV.fetch("ADMIN_EMAIL") { abort("admin:bootstrap — set ADMIN_EMAIL") }
    password = ENV.fetch("ADMIN_PASSWORD") { abort("admin:bootstrap — set ADMIN_PASSWORD") }
    # Default username = local part of email (must stay unique and format-valid).
    username = ENV["ADMIN_USERNAME"].presence || email.split("@", 2).first.presence || abort("admin:bootstrap — cannot derive username from ADMIN_EMAIL")

    if User.where("lower(email) = ?", email.downcase).exists?
      puts "admin:bootstrap — user already exists for email #{email}; nothing to do."
      next
    end

    if User.where("lower(username) = ?", username.downcase).where.not("lower(email) = ?", email.downcase).exists?
      abort "admin:bootstrap — username #{username.inspect} is already taken; set ADMIN_USERNAME to a free value."
    end

    user = User.new(
      email: email,
      username: username,
      role: "admin",
      password: password,
      password_confirmation: password,
      signup_verified_at: Time.current,
      skip_login_otp: true
    )

    if user.valid?
      user.save!
    elsif ENV["ADMIN_BOOTSTRAP_RELAX_PASSWORD_POLICY"] == "1"
      # Intentional escape hatch for initial provisioning when operators choose a password outside app rules.
      warn "admin:bootstrap — ADMIN_BOOTSTRAP_RELAX_PASSWORD_POLICY=1: saving without full validations; rotate password after first login."
      user.save!(validate: false)
    else
      warn "admin:bootstrap — validation failed: #{user.errors.full_messages.join(', ')}"
      abort "admin:bootstrap — fix password (uppercase, digit, one of !@#$%^&*) or set ADMIN_BOOTSTRAP_RELAX_PASSWORD_POLICY=1 once."
    end

    puts "admin:bootstrap — created admin id=#{user.id} email=#{user.email} username=#{user.username}"
  end
end
