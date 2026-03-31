namespace :stock_prices do
  desc "Update stock prices/candles from yfinance (same universe as market_data:refresh_all)"
  task update: :environment do
    puts "Enqueuing market data refresh jobs..."
    MarketData::NestakTop30::ALL_REFRESH_SYMBOLS.each do |sym|
      StockPriceUpdateJob.perform_later(sym)
    end
    puts "Queued #{MarketData::NestakTop30::ALL_REFRESH_SYMBOLS.size} symbols."
  end

  desc "Fetch and add a new stock price"
  task :add, [ :symbol ] => :environment do |_task, args|
    symbol = args[:symbol]&.upcase
    abort "Usage: rails stock_prices:add[AAPL]" if symbol.blank?

    service = StockPriceService.new
    result = service.get_price(symbol)

    if result
      puts "Fetched #{result[:symbol]}: $#{result[:price]}"
    else
      puts "Failed to fetch #{symbol}"
    end
  end
end
