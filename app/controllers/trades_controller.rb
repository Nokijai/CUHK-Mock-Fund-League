class TradesController < ApplicationController
  before_action :set_trade, only: [ :show ]
  before_action :set_portfolio, only: [ :index, :new, :create ]

  def index
    @trades = @portfolio.trades
  end

  def show
  end

  def new
    sym = params[:prefill_symbol].to_s.upcase.presence
    pr = params[:prefill_price]
    price = pr.present? ? BigDecimal(pr.to_s) : nil
    @trade = Trade.new(portfolio: @portfolio, symbol: sym, price: price)
    assign_available_stocks
    assign_focus_quote
  end

  def create
    @trade = Trade.new(trade_params.merge(portfolio: @portfolio))
    if @trade.save
      redirect_to @portfolio, notice: "Trade was successfully executed."
    else
      assign_available_stocks
      assign_focus_quote
      render :new, status: :unprocessable_entity
    end
  end

  private

  # Filters the reference list by optional GET/POST param :q (same semantics as StockPriceService / stocks#search).
  def assign_available_stocks
    q = params[:q].to_s.strip
    @available_stocks = if q.present?
      StockPrice.matching_query(q).order(:symbol)
    else
      StockPrice.order(:symbol)
    end
  end

  # Loads DB-backed candles per interval for the focused ticker (broker-style quote strip).
  # Focus = explicit prefill, single search hit, or the order form symbol after validation errors.
  def assign_focus_quote
    @focus_symbol = resolve_focus_symbol
    return if @focus_symbol.blank?

    @focus_stock = StockPrice.find_by(symbol: @focus_symbol)
    @focus_name = MarketData::NestakTop30::DISPLAY_NAMES[@focus_symbol] || @focus_symbol

    @candles_by_interval = StockCandle::INTERVALS.index_with do |interval|
      StockCandle
        .for_symbol(@focus_symbol)
        .for_interval(interval)
        .recent_first
        .limit(150)
        .to_a
        .reverse
    end

    @stats_by_interval = @candles_by_interval.transform_values do |candles|
      interval_stats(candles, @focus_stock)
    end

    # Which timeframe tab is shown (buttons + optional hidden field on POST).
    @quote_interval = normalize_quote_interval(params[:quote_interval])
  end

  def normalize_quote_interval(raw)
    iv = raw.to_s
    StockCandle::INTERVALS.include?(iv) ? iv : "1d"
  end

  def resolve_focus_symbol
    p = params[:prefill_symbol].to_s.strip
    return p.upcase if p.present?

    if params[:q].to_s.strip.present? && @available_stocks.size == 1
      return @available_stocks.first.symbol
    end

    @trade&.symbol.to_s.upcase.presence
  end

  # Summarizes the visible window: last OHLCV, change vs prior bar, and period high/low.
  def interval_stats(candles, stock_price_row)
    last_px = stock_price_row&.price&.to_f
    if candles.blank?
      return {
        last: last_px,
        open: nil, high: nil, low: nil, close: nil,
        chg_pct: nil, volume: nil, period_high: nil, period_low: nil, bars: 0
      }
    end

    last_c = candles.last
    prev_c = candles.size >= 2 ? candles[-2] : nil
    close = last_c.close&.to_f
    prev_close = prev_c&.close&.to_f
    chg_pct = if prev_close.present? && prev_close.nonzero?
      ((close - prev_close) / prev_close) * 100.0
    end

    highs = candles.map { |c| c.high&.to_f }.compact
    lows = candles.map { |c| c.low&.to_f }.compact

    {
      last: close,
      open: last_c.open&.to_f,
      high: last_c.high&.to_f,
      low: last_c.low&.to_f,
      close: close,
      chg_pct: chg_pct,
      volume: last_c.volume&.to_f,
      period_high: highs.max,
      period_low: lows.min,
      bars: candles.size
    }
  end

  def set_trade
    @trade = Trade.find(params[:id])
  end

  def set_portfolio
    @portfolio = Portfolio.find(params[:portfolio_id])
  end

  def trade_params
    params.require(:trade).permit(:symbol, :trade_type, :quantity, :price)
  end
end
