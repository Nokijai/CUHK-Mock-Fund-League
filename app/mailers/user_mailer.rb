class UserMailer < ApplicationMailer
  def welcome_email(user)
    @user = user
    mail(to: @user.email, subject: "Welcome to Mock-Fund League")
  end

  def login_otp_email(user, code)
    @user = user
    @code = code
    @expires_in_minutes = (User::LOGIN_OTP_TTL / 60).to_i

    mail(to: @user.email, subject: "Your Mock-Fund League login verification code")
  end
end
