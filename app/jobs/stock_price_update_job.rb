class StockPriceUpdateJob < ApplicationJob
  queue_as :default

  def perform(symbol)
    # This job refreshes market data periodically; request handlers read DB only.
    MarketData::RefreshSymbolService.new.call(symbol)
  end
end
