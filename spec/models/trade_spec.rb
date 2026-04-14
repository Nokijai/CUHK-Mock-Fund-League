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

    it "rejects a sell when the portfolio does not hold enough shares" do
      league = create(:league)
      portfolio = create(:portfolio, league:, cash_balance: 1000, total_value: 1000)
      create(:stock_price, symbol: "AAPL", price: 100.0)

      trade = described_class.new(
        portfolio:,
        symbol: "AAPL",
        trade_type: "sell",
        order_type: "market",
        quantity: 5
      )

      expect(trade).not_to be_valid
      expect(trade.errors[:base]).to include("Insufficient holding quantity to sell")
    end

    it "keeps a limit order pending until the trigger price is reached" do
      league = create(:league)
      portfolio = create(:portfolio, league:, cash_balance: 1_000, total_value: 1_000)
      create(:stock_price, symbol: "AAPL", price: 100.0)

      trade = described_class.create!(
        portfolio:,
        symbol: "AAPL",
        trade_type: "buy",
        order_type: "limit",
        quantity: 1,
        price: 90.0
      )

      expect(trade.executed_at).to be_nil
      expect(described_class.pending_limits).to include(trade)

      expect(trade.try_execute_pending_limit!).to be(false)

      StockPrice.find_by!(symbol: "AAPL").update!(price: 85.0)

      described_class.process_pending_limits!(portfolio:)

      expect(trade.reload.executed_at).to be_present
    end

    it "requires team membership before trading in team mode leagues" do
      league = create(:league, team_mode: true, team_min_participants: 1, team_max_participants: 4)
      user = create(:user)
      portfolio = create(:portfolio, user:, league:, cash_balance: 1_000, total_value: 1_000)
      create(:stock_price, symbol: "AAPL", price: 100.0)
      Team.create!(league:, name: "Alpha", password: "Secret123!", password_confirmation: "Secret123!")

      trade = described_class.new(
        portfolio:,
        symbol: "AAPL",
        trade_type: "buy",
        order_type: "market",
        quantity: 1
      )

      expect(trade).not_to be_valid
      expect(trade.errors[:base]).to include("You must join a team before trading in this league")
    end
  end
end
