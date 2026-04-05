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

    describe ".find_for_database_authentication", :skip_in_ci do
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

  describe "login OTP", :skip_in_ci do
    let(:user) { create(:user) }

    describe "#generate_login_otp!" do
      it "generates a 6-digit OTP code" do
        code = user.generate_login_otp!
        expect(code).to match(/^\d{6}$/)
      end

      it "persists login_otp_digest" do
        user.generate_login_otp!
        expect(user.reload.login_otp_digest).to be_present
      end
    end
  end
end
