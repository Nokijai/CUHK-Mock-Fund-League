class StockPriceService
  def initialize
    @client = ApiClients::YahooFinanceClient.new
  end

  def search(query)
    q = query.to_s.strip
    return [] if q.blank?

    # Search is DB-backed; external API fetching happens only via background jobs.
    StockPrice.matching_query(q).order(:symbol).limit(25).map { |sp| serialize_price(sp) }
  end

  def get_price(symbol)
    sym = symbol.to_s.upcase
    return nil if sym.blank?

    # Always read from DB; do not call external APIs here.
    sp = StockPrice.find_by(symbol: sym)
    candle = latest_candle_for(sym)

    # Prefer stock_prices for fresh values, but fall back to newest candle close.
    effective_price =
      if should_fallback_to_candle?(sp, candle)
        candle&.close
      else
        sp&.price
      end

    return nil if effective_price.nil?

    {
      symbol: sym,
      price: effective_price.to_f,
      updated_at: effective_timestamp(sp, candle)&.iso8601
    }
  end

  # Direct Yahoo quote access for consumers that still need raw provider payload.
  def get_quote(symbol)
    @client.quote(symbol)
  end

  # Direct Yahoo history access used by simpler chart consumers.
  def get_history(symbol, range: "1mo")
    @client.history(symbol, range: range)
  end

  # Batch refreshes tracked symbols; stores latest quote into stock_prices.
  def update_all_prices
    updated = []
    failed = []

    StockPrice.find_each do |stock|
      quote = @client.quote(stock.symbol)
      if quote && quote[:price]
        stock.update!(price: quote[:price], updated_at: quote[:updated_at] || Time.current)
        updated << stock.symbol
      else
        failed << stock.symbol
      end
      sleep(0.5) # Basic rate limiting for upstream API.
    end

    { updated: updated, failed: failed }
  end

  private

  # Prefer 1d close for a stable "last price", then fall back to any latest interval.
  def latest_candle_for(symbol)
    StockCandle.for_symbol(symbol).for_interval("1d").recent_first.first ||
      StockCandle.for_symbol(symbol).recent_first.first
  end

  # Seeds use 100.0 placeholders; treat that as fallback-eligible when candles exist.
  def placeholder_seed_price?(price)
    !price.nil? && price.to_d == BigDecimal("100.0")
  end

  def should_fallback_to_candle?(stock_price_row, candle)
    return false if candle.nil? || candle.close.nil?
    return true if stock_price_row.nil? || stock_price_row.price.nil?
    return true if placeholder_seed_price?(stock_price_row.price)

    stock_updated_at = stock_price_row.updated_at
    stock_updated_at.nil? || candle.candle_at > stock_updated_at
  end

  def effective_timestamp(stock_price_row, candle)
    return candle&.candle_at if should_fallback_to_candle?(stock_price_row, candle)

    stock_price_row&.updated_at
  end

  def serialize_price(sp)
    {
      symbol: sp.symbol,
      price: sp.price&.to_f,
      updated_at: sp.updated_at&.iso8601
    }
  end
end
