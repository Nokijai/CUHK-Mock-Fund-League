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

    it "detects configured handling fee including zero percent" do
      no_fee = build(:league)
      expect(no_fee.handling_fee_rule_configured?).to be(false)

      zero_fee = build(:league, rules: { "handling_fee_proportion" => "0.0" })
      expect(zero_fee.handling_fee_rule_configured?).to be(true)
    end

    it "disallows changing rules after the league is created" do
      league = create(:league, rules: { "max_participants" => 10 })
      league.max_participants = 20
      expect(league).not_to be_valid
      expect(league.errors[:rules].join).to include("cannot be changed")
    end

    it "disallows changing starting_capital after the league is created" do
      league = create(:league, starting_capital: 50_000)
      league.starting_capital = 75_000
      expect(league).not_to be_valid
      expect(league.errors[:starting_capital].join).to include("cannot be changed")
    end

    it "reports capacity reached for configured max participants" do
      # max_participants must be set at create; rules cannot change after persist.
      league = create(:league, rules: { "max_participants" => 1 })
      create(:league_membership, league:)

      expect(league.full_for_new_members?).to be(true)
    end
  end
end
