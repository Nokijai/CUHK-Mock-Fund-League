require "rails_helper"

RSpec.describe League, type: :model do
  describe "management time rules" do
    it "requires start_date to be after current time when management rules are enforced" do
      league = build(:league, start_date: 1.minute.ago, end_date: 1.day.from_now)
      league.enforce_management_time_rules = true

      expect(league).not_to be_valid
      expect(league.errors[:start_date]).to include("must be after current time")
    end

    it "requires year to be 4 digits when management rules are enforced" do
      league = build(:league)
      league.start_date = DateTime.new(10_000, 1, 1, 0, 0, 0)
      league.end_date = DateTime.new(10_000, 1, 2, 0, 0, 0)
      league.enforce_management_time_rules = true

      expect(league).not_to be_valid
      expect(league.errors[:start_date]).to include("year must be 4 digits")
      expect(league.errors[:end_date]).to include("year must be 4 digits")
    end
  end

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

    it "allows changing rules before the league starts" do
      league = create(:league, rules: { "max_participants" => 10 }, start_date: 2.days.from_now, end_date: 5.days.from_now)
      league.max_participants = 20
      expect(league).to be_valid
    end

    it "allows changing starting_capital before the league starts" do
      league = create(:league, starting_capital: 50_000, start_date: 2.days.from_now, end_date: 5.days.from_now)
      league.starting_capital = 75_000
      expect(league).to be_valid
    end

    it "disallows changing values after the league has started" do
      league = create(:league, starting_capital: 50_000, start_date: 2.days.ago, end_date: 2.days.from_now)
      league.starting_capital = 75_000
      league.max_participants = 20
      expect(league).not_to be_valid
      expect(league.errors[:base]).to include("League cannot be edited after it has started")
    end

    it "reports capacity reached for configured max participants" do
      # max_participants must be set at create; rules cannot change after persist.
      league = create(:league, rules: { "max_participants" => 1 })
      create(:league_membership, league:)

      expect(league.full_for_new_members?).to be(true)
    end
  end

  describe "join and quit windows" do
    it "allows joining before start and while running, and blocks after end" do
      league = build(:league, start_date: 1.day.from_now, end_date: 2.days.from_now)

      expect(league.join_open_now?(at: Time.current)).to be(true)
      expect(league.join_open_now?(at: league.start_date + 1.hour)).to be(true)
      expect(league.join_open_now?(at: league.end_date + 1.second)).to be(false)
    end

    it "allows quitting only before start" do
      league = build(:league, start_date: 1.day.from_now, end_date: 2.days.from_now)

      expect(league.quit_open_now?(at: Time.current)).to be(true)
      expect(league.quit_open_now?(at: league.start_date)).to be(false)
      expect(league.quit_open_now?(at: league.start_date + 1.hour)).to be(false)
    end
  end
end
