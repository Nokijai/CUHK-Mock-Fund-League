class StockPriceUpdateJob < ApplicationJob
  queue_as :default

  def perform(symbol)
    StockPriceService.new.get_price(symbol)
  end
end
