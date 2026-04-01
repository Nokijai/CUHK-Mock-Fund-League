require "rails_helper"

RSpec.describe StockPriceService do
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
  end
end
