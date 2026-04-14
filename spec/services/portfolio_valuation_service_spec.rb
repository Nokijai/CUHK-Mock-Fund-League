require "rails_helper"

RSpec.describe PortfolioValuationService do
  describe "#preload_symbols" do
    it "prefetches prices into the local cache" do
      create(:stock_price, symbol: "AAPL", price: 120)
      create(:stock_price, symbol: "MSFT", price: 250)

      service = described_class.new
      service.preload_symbols([ "aapl", "AAPL", "MSFT" ])

      expect(service.price_for_symbol("aapl")).to eq(BigDecimal("120"))
      expect(service.price_for_symbol("msft")).to eq(BigDecimal("250"))
    end
  end

  describe "#holdings_market_value" do
    it "adds up the market value of each holding" do
      league = create(:league)
      portfolio = create(:portfolio, league:, cash_balance: 10_000)
      create(:stock_price, symbol: "AAPL", price: 100)
      create(:stock_price, symbol: "MSFT", price: 250)
      create(:holding, portfolio:, symbol: "AAPL", quantity: 10, average_cost: 80)
      create(:holding, portfolio:, symbol: "MSFT", quantity: 4, average_cost: 200)

      service = described_class.new

      expect(service.holdings_market_value(portfolio)).to eq(BigDecimal("2000"))
      expect(service.total_value(portfolio)).to eq(BigDecimal("12000"))
    end
  end

  describe "#calculate" do
    it "persists the total value for a saved portfolio" do
      league = create(:league)
      portfolio = create(:portfolio, league:, cash_balance: 5_000, total_value: 0)
      create(:stock_price, symbol: "AAPL", price: 100)
      create(:holding, portfolio:, symbol: "AAPL", quantity: 10, average_cost: 90)

      service = described_class.new
      value = service.calculate(portfolio)

      expect(value).to eq(6000.0)
      expect(portfolio.reload.total_value).to eq(6000.0)
    end
  end
end
