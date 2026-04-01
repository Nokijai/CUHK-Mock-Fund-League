class StockPriceService
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

    # Prefer stock_prices for fresh values, but fall back to the newest candle close when
    # the row is missing/stale/seed-placeholder. This keeps quote strips usable right after
    # seeding or partial refreshes where candles are newer than stock_prices.
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

    # Candle data is the fresher source if its bar timestamp is newer than stock row update.
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
