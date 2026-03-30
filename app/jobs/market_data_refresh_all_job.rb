# Enqueues per-symbol yfinance refresh jobs for the Nestak watchlist + extras.
# Scheduled via Solid Queue (config/recurring.yml); each StockPriceUpdateJob
# persists latest price and candles to the DB.
class MarketDataRefreshAllJob < ApplicationJob
  queue_as :default

  def perform
    MarketData::NestakTop30::ALL_REFRESH_SYMBOLS.each do |sym|
      StockPriceUpdateJob.perform_later(sym)
    end
  end
end
