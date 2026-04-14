require "rails_helper"

RSpec.describe MarketDataRefreshAllJob, type: :job do
  describe "#perform" do
    it "fetches symbol payloads and persists each payload for full profile" do
      symbols = %w[AAPL TSLA]
      payloads = [ { "symbol" => "AAPL" }, { "symbol" => "TSLA" } ]

      stub_const("MarketData::NestakTop30::ALL_REFRESH_SYMBOLS", symbols)

      client = instance_double(MarketData::YfinanceMarketDataService, fetch_symbols: payloads)
      persister = instance_double(MarketData::RefreshSymbolService)

      allow(MarketData::YfinanceMarketDataService).to receive(:new).and_return(client)
      allow(MarketData::RefreshSymbolService).to receive(:new).with(client: client).and_return(persister)
      allow(persister).to receive(:call_payload)

      described_class.perform_now(profile: "full")

      expect(client).to have_received(:fetch_symbols).with(
        symbols,
        intervals: MarketData::YfinanceMarketDataService::DEFAULT_INTERVALS,
        period_by_interval: MarketData::YfinanceMarketDataService::FULL_PERIOD_BY_INTERVAL
      )
      expect(persister).to have_received(:call_payload).with(payloads[0])
      expect(persister).to have_received(:call_payload).with(payloads[1])
    end
  end
end
