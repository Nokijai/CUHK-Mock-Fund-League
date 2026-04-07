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
    it "returns nil for non-existent user" do
      found = User.find_for_database_authentication(email: "nonexistent@example.com")
      expect(found).to be_nil
    end
  end
end
