class StockPriceService
  def initialize
    @client = ApiClients::YahooFinanceClient.new
  end

  def search(query)
    # Basic search - returns symbols that match
    StockPrice.where("symbol ILIKE ?", "%#{query}%").pluck(:symbol)
  end

  def get_price(symbol)
    quote = @client.quote(symbol)
    return nil unless quote && quote[:price]

    stock_price = StockPrice.find_or_initialize_by(symbol: symbol.upcase)
    stock_price.update!(price: quote[:price])
    stock_price
  end

  def get_quote(symbol)
    @client.quote(symbol)
  end

  def get_history(symbol, range: "1mo")
    @client.history(symbol, range: range)
  end

  def update_all_prices
    updated = []
    failed = []

    StockPrice.find_each do |stock|
      result = get_price(stock.symbol)
      if result
        updated << stock.symbol
      else
        failed << stock.symbol
      end
      sleep(0.5) # Rate limiting
    end

    { updated: updated, failed: failed }
  end
end
