class StocksController < ApplicationController
  def search
    @results = StockPriceService.new.search(params[:q])
    render json: @results
  end

  def show
    sym = params[:symbol].to_s.upcase
    # Poll endpoint is a natural place to settle pending limit orders for this symbol.
    Trade.process_pending_limits!(symbols: sym)

    # Lightweight poll fingerprint for trading UI (price row + any candle upserts).
    if params[:meta].present?
      sp = StockPrice.find_by(symbol: sym)
      return render json: { error: "Stock not found" }, status: :not_found unless sp
      candle_ts = StockCandle.where(symbol: sym).maximum(:updated_at)
      rev = [ sp.updated_at, candle_ts ].compact.max
      return render json: { symbol: sym, revision: rev&.iso8601(6) }
    end

    # Fetch stock data from service
    payload = StockPriceService.new.get_price(sym)
    
    # Handle not found cases
    unless payload
      respond_to do |format|
        format.json { render json: { error: "Stock not found" }, status: :not_found }
        format.html { 
          flash[:alert] = "Stock #{sym} not found"
          redirect_to root_path 
        }
      end
      return
    end

    # Single fingerprint for poll: max(price row update, any candle row update).
    sp_row = StockPrice.find_by(symbol: sym)
    candle_ts = StockCandle.where(symbol: sym).maximum(:updated_at)
    revision = [ sp_row&.updated_at, candle_ts ].compact.max
    payload = payload.merge(revision: revision&.iso8601(6))

    # DB-only; candles are persisted by background jobs. OHLCV for charts / API clients.
    interval = params[:interval].to_s.presence || "1d"
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

    # Respond to different formats
    respond_to do |format|
      format.json { render json: payload }
      format.html { 
        # Prepare data for HTML view
        @stock = sp_row
        @symbol = sym
        @price_data = payload
        @candles = candles
        @interval = interval
        render :show
      }
    end
  end
end
