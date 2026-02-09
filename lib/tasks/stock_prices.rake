namespace :stock_prices do
  desc "Update stock prices from API"
  task update: :environment do
    StockPrice.find_each do |sp|
      StockPriceUpdateJob.perform_later(sp.symbol)
    end
  end
end
