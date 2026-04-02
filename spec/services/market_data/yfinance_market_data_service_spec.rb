require "rails_helper"

RSpec.describe MarketData::YfinanceMarketDataService do
  describe "#fetch_symbol" do
    it "uses configured python binary and parses payload" do
      service = described_class.new
      payload = {
        symbols: [
          {
            symbol: "NVDA",
            price: 123.45,
            candles: { "1d" => [] }
          }
        ]
      }.to_json

      allow(ENV).to receive(:fetch).with("MARKET_DATA_PYTHON_BIN", "python3").and_return("python-custom")
      allow(Open3).to receive(:capture3).and_return([ payload, "", instance_double(Process::Status, success?: true) ])

      result = service.fetch_symbol("nvda", intervals: [ "1d" ])

      expect(result["symbol"]).to eq("NVDA")
      expect(result["price"]).to eq(123.45)
      expect(Open3).to have_received(:capture3).with(
        "python-custom",
        Rails.root.join("scripts/yfinance_fetch.py").to_s,
        "--symbols",
        "NVDA",
        "--intervals",
        "1d",
        "--timeout-seconds",
        "20",
        "--period-overrides",
        "{}"
      )
    end

    it "raises with stderr when command fails" do
      service = described_class.new
      allow(Open3).to receive(:capture3).and_return([ "", "boom", instance_double(Process::Status, success?: false) ])

      expect do
        service.fetch_symbol("NVDA", intervals: [ "1d" ])
      end.to raise_error(/yfinance batch fetch failed/)
    end
  end
end
