# Batch refreshes yfinance data for the Nestak watchlist + extras.
# Scheduled via Solid Queue (config/recurring.yml), then persisted to DB.
class MarketDataRefreshAllJob < ApplicationJob
  queue_as :default

  # Profile controls fetch depth:
  # - fast: frequent short-window refresh for responsiveness
  # - full: less frequent deep-window refresh for broader history
  def perform(profile: "fast")
    symbols = MarketData::NestakTop30::ALL_REFRESH_SYMBOLS
    client = MarketData::YfinanceMarketDataService.new
    persister = MarketData::RefreshSymbolService.new(client:)
    period_by_interval = profile.to_s == "full" ? MarketData::YfinanceMarketDataService::FULL_PERIOD_BY_INTERVAL : MarketData::YfinanceMarketDataService::FAST_PERIOD_BY_INTERVAL

    # Single batch fetch avoids starting a Python process per symbol.
    payloads = client.fetch_symbols(
      symbols,
      intervals: MarketData::YfinanceMarketDataService::DEFAULT_INTERVALS,
      period_by_interval:
    )

    payloads.each do |payload|
      persister.call_payload(payload)
    end
  end
end
