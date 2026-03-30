class StocksController < ApplicationController
  def search
    @results = StockPriceService.new.search(params[:q])
    render json: @results
  end

  def show
    sym = params[:symbol].to_s.upcase

    # Lightweight poll fingerprint for trading UI (price row + any candle upserts).
    if params[:meta].present?
      sp = StockPrice.find_by(symbol: sym)
      return render json: { error: "Stock not found" }, status: :not_found unless sp
      candle_ts = StockCandle.where(symbol: sym).maximum(:updated_at)
      rev = [ sp.updated_at, candle_ts ].compact.max
      return render json: { symbol: sym, revision: rev&.iso8601(6) }
    end

    payload = StockPriceService.new.get_price(sym)
    return render json: { error: "Stock not found" }, status: :not_found unless payload

    # Single fingerprint for poll: max(price row update, any candle row update).
    sp_row = StockPrice.find_by(symbol: sym)
    candle_ts = StockCandle.where(symbol: sym).maximum(:updated_at)
    revision = [ sp_row&.updated_at, candle_ts ].compact.max
    payload = payload.merge(revision: revision&.iso8601(6))

    # DB-only; candles are persisted by background jobs. OHLCV for charts / API clients.
    interval = params[:interval].to_s.presence
    if interval.present?
      candles = StockCandle
        .for_symbol(sym)
        .for_interval(interval)
        .recent_first
        .limit(200)
        .map do |c|
          {
            t: c.candle_at.iso8601,
            o: c.open&.to_f,
            h: c.high&.to_f,
            l: c.low&.to_f,
            c: c.close&.to_f,
            v: c.volume&.to_f
          }
        end
      payload = payload.merge(interval:, candles:)
    end

    render json: payload
  end
end
