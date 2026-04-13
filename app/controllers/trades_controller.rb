class TradesController < ApplicationController
  before_action :set_trade, only: [ :show ]
  before_action :set_portfolio, only: [ :index, :new, :create ]

  def index
    @trades = @portfolio.trades
  end

  def show
  end

  def new
    # Only process limits for this portfolio — not the entire system.
    Trade.process_pending_limits!(portfolio: @portfolio)
    sym = params[:prefill_symbol].to_s.upcase.presence
    pr = params[:prefill_price]
    price = pr.present? ? BigDecimal(pr.to_s) : nil
    tt = params[:prefill_trade_type].to_s.downcase
    side = %w[buy sell].include?(tt) ? tt : "buy"
    @trade = Trade.new(
      portfolio: @portfolio,
      symbol: sym,
      price: price,
      order_type: "market",
      trade_type: side
    )
    assign_portfolio_holdings_summary
    assign_available_stocks
    assign_focus_quote
  end

  def create
    @trade = Trade.new(trade_params.merge(portfolio: @portfolio))
    if @trade.save
      Trade.process_pending_limits!(portfolio: @portfolio, symbols: @trade.symbol)
      msg = @trade.executed_at.present? ? "Order executed successfully." : "Limit order placed and pending execution."
      redirect_to new_portfolio_trade_path(
        @portfolio,
        q: @trade.symbol,
        quote_interval: params[:quote_interval],
        league_id: @portfolio.league_id
      ), notice: msg
    else
      flash.now[:alert] = @trade.errors.full_messages.presence&.to_sentence ||
                          "Order could not be processed."
      assign_portfolio_holdings_summary
      assign_available_stocks
      assign_focus_quote
      render :new, status: :unprocessable_entity
    end
  end

  private

  # Holdings in the active portfolio (this league) for the trading sidebar summary.
  def assign_portfolio_holdings_summary
    @portfolio_holdings = @portfolio.holdings.order(:symbol).to_a
    syms = @portfolio_holdings.map(&:symbol)
    @holding_stock_prices = syms.empty? ? {} : StockPrice.where(symbol: syms).index_by(&:symbol)
  end

  # Filters the reference list by optional GET/POST param :q (same semantics as StockPriceService / stocks#search).
  def assign_available_stocks
    q = params[:q].to_s.strip
    @available_stocks = if q.present?
      StockPrice.matching_query(q).order(:symbol)
    else
      # Only load tracked symbols by default to avoid a full table scan.
      StockPrice.where(symbol: MarketData::NestakTop30::ALL_REFRESH_SYMBOLS).order(:symbol)
    end.to_a
  end

  # Loads DB-backed candles per interval for the focused ticker (broker-style quote strip).
  # Focus = explicit prefill, single search hit, or the order form symbol after validation errors.
  def assign_focus_quote
    # Which timeframe tab is shown (buttons + optional hidden field on POST).
    @quote_interval = normalize_quote_interval(params[:quote_interval])
    @focus_symbol = resolve_focus_symbol
    return if @focus_symbol.blank?

    # Evaluate pending limits for the focused symbol in this portfolio only.
    # new/create already evaluate pending limits; skip duplicate pass here.

    @focus_stock = StockPrice.find_by(symbol: @focus_symbol)
    @focus_name = MarketData::NestakTop30::DISPLAY_NAMES[@focus_symbol] || @focus_symbol
    @focus_holding = @portfolio.holdings.find_by(symbol: @focus_symbol)
    @focus_cash_balance = @portfolio.cash_balance.to_d

    # Load only the active interval for this render. Other tabs request their own page load.
    candles = StockCandle
      .for_symbol(@focus_symbol)
      .for_interval(@quote_interval)
      .recent_first
      .limit(150)
      .to_a
      .reverse
    # Some providers can emit more than one timestamp for a "daily" bar.
    # Keep one candle per trading day so 1D history/table stays clean.
    candles = collapse_daily_candles(candles, @quote_interval)
    @candles_by_interval = { @quote_interval => candles }

    @stats_by_interval = { @quote_interval => interval_stats(candles, @focus_stock) }

    # Reuse loaded rows to avoid another DB round-trip in helper revision fingerprint.
    max_candle_updated_at = candles.map(&:updated_at).compact.max
    @quote_revision = [ @focus_stock&.updated_at, max_candle_updated_at ].compact.max&.iso8601(6).to_s
  end

  def normalize_quote_interval(raw)
    iv = raw.to_s
    StockCandle::INTERVALS.include?(iv) ? iv : "1d"
  end

  def resolve_focus_symbol
    p = params[:prefill_symbol].to_s.strip
    return p.upcase if p.present?

    if params[:q].to_s.strip.present? && @available_stocks.length == 1
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
    chg_pct = if close.present? && prev_close.present? && prev_close.nonzero?
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

  # Deduplicates 1d candles by market date while preserving chronological order.
  # For duplicate dates, keep the latest timestamp entry as the canonical daily bar.
  def collapse_daily_candles(candles, interval)
    return candles unless interval.to_s == "1d"

    candles_by_day = {}
    candles.each do |candle|
      market_day = candle.candle_at.in_time_zone("America/New_York").to_date
      candles_by_day[market_day] = candle
    end
    candles_by_day.values
  end

  def set_trade
    @trade = Trade.find(params[:id])
  end

  def set_portfolio
    # Reuse preloaded nav context from ApplicationController to avoid repeat queries.
    if @joined_leagues.blank?
      redirect_to leagues_path, alert: "Please join a league first."
      return
    end

    if params[:league_id].present?
      # Membership already loaded by set_terminal_nav_context; look up in-memory.
      @portfolio = @league_portfolio_map[params[:league_id].to_i]
      unless @portfolio
        redirect_to leagues_path, alert: "Please select a league you joined."
        return
      end
    else
      @portfolio = @league_portfolio_map.values.find { |p| p.id == params[:portfolio_id].to_i } ||
                   current_user.portfolios.find(params[:portfolio_id])
    end

    # Prefer preloaded league object to avoid an extra association query.
    @selected_league = @joined_leagues.find { |league| league.id == @portfolio.league_id } || @portfolio.league
    @nav_league = @selected_league
    @nav_portfolio = @portfolio
  end

  def trade_params
    params.require(:trade).permit(:symbol, :trade_type, :order_type, :quantity, :price)
  end
end
