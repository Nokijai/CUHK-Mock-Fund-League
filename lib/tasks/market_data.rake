namespace :market_data do
  desc "Refresh Nestak top 30 (+ HK extras) from yfinance via background jobs"
  task refresh_all: :environment do
    symbols = MarketData::NestakTop30::ALL_REFRESH_SYMBOLS
    symbols.each do |sym|
      StockPriceUpdateJob.perform_later(sym)
    end
    puts "Enqueued #{symbols.size} symbols: #{symbols.join(', ')}"
  end
end
