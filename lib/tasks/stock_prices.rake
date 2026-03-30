namespace :stock_prices do
  desc "Update stock prices/candles from yfinance (same universe as market_data:refresh_all)"
  task update: :environment do
    MarketData::NestakTop30::ALL_REFRESH_SYMBOLS.each do |sym|
      StockPriceUpdateJob.perform_later(sym)
    end
  end
end
