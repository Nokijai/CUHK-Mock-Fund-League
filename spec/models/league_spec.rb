require "rails_helper"

RSpec.describe League, type: :model do
  describe "admin-configured rule fields" do
    it "stores structured rule values inside rules json" do
      league = build(:league)
      league.max_participants = "40"
      league.handling_fee_proportion = "0.0025"
      league.minimum_final_balance = "85000"

      expect(league.rules["max_participants"]).to eq(40)
      expect(league.rules["handling_fee_proportion"]).to eq("0.0025")
      expect(league.rules["minimum_final_balance"]).to eq("85000.0")
    end

    it "validates handling fee proportion within 0..1" do
      league = build(:league)
      league.handling_fee_proportion = "1.5"

      expect(league).not_to be_valid
      expect(league.errors[:handling_fee_proportion]).to include("must be between 0 and 1")
    end

    it "reports capacity reached for configured max participants" do
      league = create(:league)
      league.max_participants = 1
      league.save!
      create(:league_membership, league:)

      expect(league.full_for_new_members?).to be(true)
    end
  end
end
