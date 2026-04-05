require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it "validates presence of username" do
      user = build(:user, username: nil)
      expect(user).not_to be_valid
      expect(user.errors[:username]).to include("can't be blank")
    end

    it "validates uniqueness of username (case insensitive)" do
      existing_user = create(:user, username: "testuser")
      new_user = build(:user, username: "TestUser")
      expect(new_user).not_to be_valid
      expect(new_user.errors[:username]).to include("has already been taken")
    end

    it "validates username format (no spaces)" do
      user = build(:user, username: "user name")
      expect(user).not_to be_valid
      expect(user.errors[:username]).to include("cannot contain spaces")
    end

    it "allows username without spaces" do
      user = build(:user, username: "username123")
      expect(user).to be_valid
    end
  end

  describe "authentication" do
    let(:user) { create(:user, email: "test@example.com", username: "testuser", password: "Test123!@#") }

    describe ".find_for_database_authentication" do
      it "finds user by email" do
        found = User.find_for_database_authentication(email: "test@example.com")
        expect(found).to eq(user)
      end

      it "finds user by username" do
        found = User.find_for_database_authentication(email: "testuser")
        expect(found).to eq(user)
      end

      it "is case insensitive for email" do
        found = User.find_for_database_authentication(email: "TEST@EXAMPLE.COM")
        expect(found).to eq(user)
      end

      it "is case insensitive for username" do
        found = User.find_for_database_authentication(email: "TESTUSER")
        expect(found).to eq(user)
      end

      it "returns nil for non-existent user" do
        found = User.find_for_database_authentication(email: "nonexistent@example.com")
        expect(found).to be_nil
      end
    end
  end

  describe "signup OTP" do
    let(:user) { create(:user) }

    describe "#generate_signup_otp!" do
      it "generates a 6-digit OTP code" do
        code = user.generate_signup_otp!
        expect(code).to match(/^\d{6}$/)
      end

      it "sets signup_otp_digest" do
        user.generate_signup_otp!
        expect(user.signup_otp_digest).to be_present
      end

      it "sets signup_otp_sent_at to current time" do
        freeze_time do
          user.generate_signup_otp!
          expect(user.signup_otp_sent_at).to eq(Time.current)
        end
      end

      it "resets signup_otp_attempts to 0" do
        user.update_column(:signup_otp_attempts, 3)
        user.generate_signup_otp!
        expect(user.signup_otp_attempts).to eq(0)
      end
    end

    describe "#verify_signup_otp!" do
      let(:code) { user.generate_signup_otp! }

      it "returns true for correct code" do
        expect(user.verify_signup_otp!(code)).to be true
      end

      it "returns false for incorrect code" do
        user.generate_signup_otp!
        expect(user.verify_signup_otp!("000000")).to be false
      end

      it "returns false for expired code" do
        code = user.generate_signup_otp!
        travel(User::SIGNUP_OTP_TTL + 1.minute) do
          expect(user.verify_signup_otp!(code)).to be false
        end
      end

      it "increments signup_otp_attempts on failed verification" do
        user.generate_signup_otp!
        expect {
          user.verify_signup_otp!("000000")
        }.to change { user.reload.signup_otp_attempts }.by(1)
      end

      it "locks user after max attempts" do
        user.generate_signup_otp!
        User::SIGNUP_OTP_MAX_ATTEMPTS.times do
          user.verify_signup_otp!("000000")
        end
        expect(user.reload.signup_otp_locked?).to be true
      end
    end
  end
end
