class StockPriceUpdateAllJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting stock price update..."
    service = StockPriceService.new
    result = service.update_all_prices
    Rails.logger.info "Updated: #{result[:updated].count}, Failed: #{result[:failed].count}"
  end
end
