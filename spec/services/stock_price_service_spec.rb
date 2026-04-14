require "rails_helper"

RSpec.describe StockPriceService do
  describe "#search" do
    it "returns matching prices in symbol order and ignores blank searches" do
      create(:stock_price, symbol: "MSFT", price: 250.0)
      aapl = create(:stock_price, symbol: "AAPL", price: 150.0)

      service = described_class.new

      expect(service.search("   ")).to eq([])
      expect(service.search("aap")).to eq([ { symbol: "AAPL", price: 150.0, updated_at: aapl.updated_at.iso8601 } ])
    end
  end

  describe "#get_price" do
    it "returns stock price when row is fresh" do
      StockPrice.create!(symbol: "NVDA", price: 120.50, updated_at: Time.current)

      result = described_class.new.get_price("nvda")

      expect(result[:symbol]).to eq("NVDA")
      expect(result[:price]).to eq(120.5)
    end

    it "falls back to latest candle close when seeded placeholder is present" do
      StockPrice.create!(symbol: "NVDA", price: 100.0, updated_at: Time.current)
      StockCandle.create!(
        symbol: "NVDA",
        interval: "1d",
        candle_at: Time.current + 2.minutes,
        open: 130.0,
        high: 131.0,
        low: 129.0,
        close: 130.25,
        volume: 1000
      )

      result = described_class.new.get_price("NVDA")

      expect(result[:price]).to eq(130.25)
    end

    it "returns nil when no effective price is available" do
      expect(described_class.new.get_price("")).to be_nil
    end
  end

  describe "#get_quote and #get_history" do
    it "delegates provider calls to the Yahoo client" do
      client = instance_double(ApiClients::YahooFinanceClient)
      allow(ApiClients::YahooFinanceClient).to receive(:new).and_return(client)
      service = described_class.new

      expect(client).to receive(:quote).with("AAPL").and_return(symbol: "AAPL")
      expect(client).to receive(:history).with("AAPL", range: "5d").and_return([ { date: "2026-04-01" } ])

      expect(service.get_quote("AAPL")).to eq(symbol: "AAPL")
      expect(service.get_history("AAPL", range: "5d")).to eq([ { date: "2026-04-01" } ])
    end
  end

  describe "#update_all_prices" do
    it "updates rows with the latest quote and collects failures" do
      aapl = create(:stock_price, symbol: "AAPL", price: 100.0)
      create(:stock_price, symbol: "MSFT", price: 200.0)

      client = instance_double(ApiClients::YahooFinanceClient)
      allow(ApiClients::YahooFinanceClient).to receive(:new).and_return(client)
      allow(client).to receive(:quote).with("AAPL").and_return(price: 125.5, updated_at: Time.current)
      allow(client).to receive(:quote).with("MSFT").and_return(nil)

      service = described_class.new
      allow(service).to receive(:sleep)

      result = service.update_all_prices

      expect(result[:updated]).to eq([ "AAPL" ])
      expect(result[:failed]).to eq([ "MSFT" ])
      expect(aapl.reload.price.to_f).to eq(125.5)
    end
  end
end
