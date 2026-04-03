require "rails_helper"

RSpec.describe Trade, type: :model do
  describe "handling fee rule integration" do
    it "deducts handling fee on buy execution" do
      league = create(:league, rules: { "handling_fee_proportion" => "0.01" })
      portfolio = create(:portfolio, league:, cash_balance: 1_000, total_value: 1_000)
      create(:stock_price, symbol: "AAPL", price: 100.0)

      trade = described_class.create(
        portfolio:,
        symbol: "AAPL",
        trade_type: "buy",
        order_type: "market",
        quantity: 5
      )

      expect(trade).to be_persisted
      expect(portfolio.reload.cash_balance.to_d).to eq(BigDecimal("495.0"))
    end

    it "rejects buy order when fee pushes cost above cash" do
      league = create(:league, rules: { "handling_fee_proportion" => "0.01" })
      portfolio = create(:portfolio, league:, cash_balance: 500, total_value: 500)
      create(:stock_price, symbol: "AAPL", price: 100.0)

      trade = described_class.new(
        portfolio:,
        symbol: "AAPL",
        trade_type: "buy",
        order_type: "market",
        quantity: 5
      )

      expect(trade).not_to be_valid
      expect(trade.errors[:base]).to include("Insufficient cash balance for this order including handling fee")
    end

    it "deducts handling fee from sell proceeds" do
      league = create(:league, rules: { "handling_fee_proportion" => "0.02" })
      portfolio = create(:portfolio, league:, cash_balance: 100, total_value: 100)
      create(:holding, portfolio:, symbol: "AAPL", quantity: 10, average_cost: 80)
      create(:stock_price, symbol: "AAPL", price: 100.0)

      trade = described_class.create(
        portfolio:,
        symbol: "AAPL",
        trade_type: "sell",
        order_type: "market",
        quantity: 5
      )

      expect(trade).to be_persisted
      expect(portfolio.reload.cash_balance.to_d).to eq(BigDecimal("590.0"))
    end
  end
end
