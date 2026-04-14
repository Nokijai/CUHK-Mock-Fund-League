require "rails_helper"

RSpec.describe LeagueRulesValidator do
  describe "#validate_trade" do
    it "returns true" do
      league = create(:league)
      validator = described_class.new(league)

      expect(validator.validate_trade({ symbol: "AAPL", quantity: 10, side: "buy" })).to eq(true)
    end
  end
end
