class PortfolioValuationJob < ApplicationJob
  queue_as :default

  def perform(portfolio_id)
    portfolio = Portfolio.find_by(id: portfolio_id)
    return unless portfolio
    PortfolioValuationService.new.calculate(portfolio)
  end
end
