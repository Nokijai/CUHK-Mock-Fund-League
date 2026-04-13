class PortfolioValuationService
  def initialize
    # Request-local quote cache to avoid repeated StockPrice queries.
    @price_cache = {}
  end

  # Optional preloader so callers can batch-fetch quote rows in one query.
  def preload_symbols(symbols)
    normalized = Array(symbols).map { |s| s.to_s.upcase }.uniq
    return if normalized.empty?

    StockPrice.where(symbol: normalized).pluck(:symbol, :price).each do |sym, price|
      @price_cache[sym] = price.to_d
    end
  end

  def price_for_symbol(symbol)
    sym = symbol.to_s.upcase
    return @price_cache[sym] if @price_cache.key?(sym)

    sp = StockPrice.find_by(symbol: sym)
    @price_cache[sym] = sp ? sp.price.to_d : 0.to_d
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
    value = total_value(portfolio).to_f
    portfolio.update_column(:total_value, value) if portfolio&.persisted?
    value
  end
end
