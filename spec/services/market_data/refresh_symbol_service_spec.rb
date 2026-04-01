require "rails_helper"

RSpec.describe MarketData::RefreshSymbolService do
  describe "#call" do
    it "persists latest price and upserts candles" do
      payload = {
        "symbol" => "NVDA",
        "price" => 101.25,
        "candles" => {
          "1d" => [
            { "t" => "2026-04-01T00:00:00Z", "o" => 100.0, "h" => 105.0, "l" => 99.0, "c" => 101.25, "v" => 1000 }
          ]
        }
      }
      client = instance_double(MarketData::YfinanceMarketDataService, fetch_symbol: payload)
      service = described_class.new(client:)

      expect(service.call("nvda")).to eq(true)

      stock_price = StockPrice.find_by(symbol: "NVDA")
      candle = StockCandle.find_by(symbol: "NVDA", interval: "1d", candle_at: Time.iso8601("2026-04-01T00:00:00Z"))

      expect(stock_price).to be_present
      expect(stock_price.price.to_f).to eq(101.25)
      expect(candle).to be_present
      expect(candle.close.to_f).to eq(101.25)
    end
  end
end
