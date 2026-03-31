#!/usr/bin/env ruby
# Run with: rails runner script/fetch_stock_prices.rb

puts "Stock price updater started. Fetching every 15 minutes..."
puts "Press Ctrl+C to stop"

loop do
  puts "\n[#{Time.current}] Fetching stock prices..."

  service = StockPriceService.new
  result = service.update_all_prices

  puts "Updated: #{result[:updated].join(', ')}" if result[:updated].any?
  puts "Failed: #{result[:failed].join(', ')}" if result[:failed].any?
  puts "Next update in 15 minutes..."

  sleep(15 * 60) # 15 minutes
end
