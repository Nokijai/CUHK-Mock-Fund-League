require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  let(:user) { create(:user, username: "alice", email: "alice@example.com") }

  describe "#welcome_email" do
    let(:mail) { described_class.welcome_email(user) }

    it "sets recipient and subject" do
      expect(mail.to).to eq([ "alice@example.com" ])
      expect(mail.subject).to eq("Welcome to Mock-Fund League")
    end
  end

  describe "#signup_otp_email" do
    let(:mail) { described_class.signup_otp_email(user, "123456") }

    it "renders signup OTP code and expiry" do
      expect(mail.to).to eq([ "alice@example.com" ])
      expect(mail.subject).to eq("Verify your Mock-Fund League signup")
      expect(mail.body.encoded).to include("123456")
      expect(mail.body.encoded).to include((User::SIGNUP_OTP_TTL / 60).to_i.to_s)
    end
  end

  describe "#login_otp_email" do
    let(:mail) { described_class.login_otp_email(user, "654321") }

    it "renders login OTP code and expiry" do
      expect(mail.to).to eq([ "alice@example.com" ])
      expect(mail.subject).to eq("Your Mock-Fund League login verification code")
      expect(mail.body.encoded).to include("654321")
      expect(mail.body.encoded).to include((User::LOGIN_OTP_TTL / 60).to_i.to_s)
    end
  end
end
