class PortfolioValuationService
  def calculate(portfolio)
    portfolio.cash_balance.to_f
  end
end
