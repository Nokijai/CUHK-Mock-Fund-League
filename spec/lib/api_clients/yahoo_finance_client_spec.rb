require "rails_helper"

RSpec.describe ApiClients::YahooFinanceClient do
  def stub_http(response)
    http = double("http")
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_return(response)
    allow(Net::HTTP).to receive(:new).and_return(http)
  end

  describe "#quote" do
    it "parses a successful quote response" do
      response = double("response", body: {
        chart: {
          result: [
            {
              meta: {
                symbol: "AAPL",
                regularMarketPrice: 123.45,
                previousClose: 121.0,
                currency: "USD",
                exchangeName: "NMS",
                regularMarketTime: 1_700_000_000
              }
            }
          ]
        }
      }.to_json)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      stub_http(response)

      quote = described_class.new.quote("AAPL")

      expect(quote[:symbol]).to eq("AAPL")
      expect(quote[:price]).to eq(123.45)
      expect(quote[:previous_close]).to eq(121.0)
      expect(quote[:updated_at]).to be_a(Time)
    end

    it "returns nil for non-successful responses" do
      response = double("response")
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
      stub_http(response)

      expect(described_class.new.quote("AAPL")).to be_nil
    end
  end

  describe "#history" do
    it "parses historical quote candles" do
      response = double("response", body: {
        chart: {
          result: [
            {
              timestamp: [ 1_700_000_000, 1_700_086_400 ],
              indicators: {
                quote: [
                  {
                    open: [ 100.1, 101.2 ],
                    high: [ 102.3, 103.4 ],
                    low: [ 99.9, 100.8 ],
                    close: [ 101.5, 102.6 ],
                    volume: [ 1_000, 2_000 ]
                  }
                ]
              }
            }
          ]
        }
      }.to_json)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      stub_http(response)

      history = described_class.new.history("AAPL", range: "5d", interval: "1d")

      expect(history.length).to eq(2)
      expect(history.first).to include(date: Time.at(1_700_000_000).to_date.to_s, open: 100.1, close: 101.5)
    end

    it "returns nil when parsing fails" do
      response = double("response", body: "not json")
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      stub_http(response)
      allow(JSON).to receive(:parse).and_raise(StandardError.new("boom"))

      expect(described_class.new.history("AAPL")).to be_nil
    end
  end
end