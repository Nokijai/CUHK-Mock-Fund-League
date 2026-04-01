class PortfolioValuationService
  def price_for_symbol(symbol)
    sp = StockPrice.find_by(symbol: symbol.to_s.upcase)
    return sp.price.to_d if sp
    0.to_d
  end

  def holdings_market_value(portfolio)
    portfolio.holdings.sum do |h|
      price_for_symbol(h.symbol) * h.quantity
    end
  end

  def total_value(portfolio)
    portfolio.cash_balance.to_d + holdings_market_value(portfolio)
  end

  def calculate(portfolio)
    total_value(portfolio).to_f
  end
end
