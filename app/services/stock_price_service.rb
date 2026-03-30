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
    sp ? serialize_price(sp) : nil
  end

  private

  def serialize_price(sp)
    {
      symbol: sp.symbol,
      price: sp.price&.to_f,
      updated_at: sp.updated_at&.iso8601
    }
  end
end
