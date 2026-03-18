namespace :stock_prices do
  desc "Update stock prices from Yahoo Finance API"
  task update: :environment do
    puts "Updating stock prices..."
    service = StockPriceService.new
    result = service.update_all_prices
    
    puts "Updated: #{result[:updated].join(', ')}" if result[:updated].any?
    puts "Failed: #{result[:failed].join(', ')}" if result[:failed].any?
    puts "Done!"
  end

  desc "Fetch and add a new stock price"
  task :add, [:symbol] => :environment do |t, args|
    symbol = args[:symbol]&.upcase
    abort "Usage: rails stock_prices:add[AAPL]" unless symbol

    service = StockPriceService.new
    result = service.get_price(symbol)
    
    if result
      puts "Added #{result.symbol}: $#{result.price}"
    else
      puts "Failed to fetch #{symbol}"
    end
  end
end
