require "rack/attack"

# Rack::Attack provides request-level throttling to complement user-level OTP locks.
# This reduces the impact of password stuffing and OTP spam attempts.
class Rack::Attack
  # Use Rails cache for counters (Solid Cache in production, memory store in development by default).
  self.cache.store = Rails.cache

  # Throttle sign-in attempts by IP address.
  throttle("auth/sign_in/ip", limit: 20, period: 60) do |req|
    req.ip if req.post? && req.path == "/users/sign_in"
  end

  # Throttle login OTP verification by IP.
  throttle("auth/login_otp/verify/ip", limit: 30, period: 60) do |req|
    req.ip if req.post? && req.path == "/users/verify_otp"
  end

  # Throttle login OTP resends by IP.
  throttle("auth/login_otp/resend/ip", limit: 10, period: 60) do |req|
    req.ip if req.post? && req.path == "/users/verify_otp/resend"
  end

  # Throttle signup OTP verification by IP.
  throttle("auth/signup_otp/verify/ip", limit: 30, period: 60) do |req|
    req.ip if req.post? && req.path == "/users/verify_signup_otp"
  end

  # Throttle signup OTP resends by IP.
  throttle("auth/signup_otp/resend/ip", limit: 10, period: 60) do |req|
    req.ip if req.post? && req.path == "/users/verify_signup_otp/resend"
  end

  # Return a consistent response to throttled requests.
  self.throttled_responder = lambda do |_request|
    [
      429,
      { "Content-Type" => "text/plain", "Retry-After" => "60" },
      [ "Too many requests. Please wait and try again." ]
    ]
  end
end
