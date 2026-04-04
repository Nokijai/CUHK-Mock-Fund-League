module TradesHelper
  def stock_name_for(symbol)
    MarketData::NestakTop30::DISPLAY_NAMES[symbol.to_s] || symbol.to_s
  end

  # Short labels for candle intervals (matches StockCandle::INTERVALS).
  def trading_interval_title(interval)
    {
      "15m" => "15 MIN",
      "1h" => "1 HOUR",
      "4h" => "4 HOUR",
      "1d" => "1 DAY"
    }[interval.to_s] || interval.to_s.upcase
  end

  # Compact button labels for interval tabs.
  def trading_interval_tab_label(interval)
    {
      "15m" => "15M",
      "1h" => "1H",
      "4h" => "4H",
      "1d" => "1D"
    }[interval.to_s] || interval.to_s.upcase
  end

  # Fingerprint for JS polling: last change to quote or any candle row for this symbol.
  def quote_revision_for(symbol)
    # Prefer controller-computed revision when candles/quote are already loaded.
    precomputed = @quote_revision.to_s
    return precomputed if precomputed.present?

    sym = symbol.to_s.upcase
    sp = StockPrice.find_by(symbol: sym)
    return "" unless sp
    candle_ts = StockCandle.where(symbol: sym).maximum(:updated_at)
    [ sp.updated_at, candle_ts ].compact.max.iso8601(6)
  end

  # JSON-serializable OHLCV rows for the trading chart (Stimulus initial state).
  def trading_quote_candles_payload(candles)
    Array(candles).map do |c|
      {
        t: c.candle_at.iso8601,
        o: c.open&.to_f,
        h: c.high&.to_f,
        l: c.low&.to_f,
        c: c.close&.to_f,
        v: c.volume&.to_f
      }
    end
  end

  # Preserves search + prefill + selected chart when switching timeframe (GET links on trading page).
  def trading_quote_link_params(interval)
    c = controller.params
    {
      # Keep league context stable while switching timeframe tabs.
      league_id: c[:league_id].presence,
      quote_interval: interval,
      q: c[:q].presence,
      prefill_symbol: c[:prefill_symbol].presence,
      prefill_price: c[:prefill_price].presence
    }.compact
  end

  # SVG candlesticks (legacy / optional); trading page uses Stimulus canvas (trading_quote_controller).
  def trading_candlestick_chart_svg(candles, width: 1000, height: 220)
    rows = candles.select { |c| c.high.present? && c.low.present? }
    if rows.empty?
      return content_tag(:p, "No chart data — run market refresh jobs.", class: "terminal-quote-chart-empty")
    end

    vals = rows.flat_map do |c|
      [ c.open, c.high, c.low, c.close ].compact.map { |x| x.to_f }
    end
    min_v = vals.min
    max_v = vals.max
    if max_v == min_v
      min_v -= 1.0
      max_v += 1.0
    end
    pad_pct = 0.04
    range = max_v - min_v
    min_v -= range * pad_pct
    max_v += range * pad_pct
    range = max_v - min_v

    side_pad = 20.0
    w = width.to_f
    h = height.to_f
    plot_h = h - 2 * side_pad
    n = rows.size
    slot_w = (w - 2 * side_pad) / n
    body_w = [ slot_w * 0.55, 2.0 ].max

    up = "#30d158"
    down = "#ff453a"
    wick = "#8e8e93"

    parts = []
    rows.each_with_index do |c, i|
      o = (c.open || c.close).to_f
      hi = c.high.to_f
      lo = c.low.to_f
      cl = (c.close || c.open).to_f

      cx = side_pad + i * slot_w + slot_w / 2.0
      yh = candle_y(hi, min_v, range, plot_h, side_pad)
      yl = candle_y(lo, min_v, range, plot_h, side_pad)
      yo = candle_y(o, min_v, range, plot_h, side_pad)
      yc = candle_y(cl, min_v, range, plot_h, side_pad)
      y_top = [ yo, yc ].min
      y_bot = [ yo, yc ].max
      body_h = [ y_bot - y_top, 1.0 ].max
      col = cl >= o ? up : down

      parts << tag.line(
        x1: cx.round(2), y1: yh.round(2), x2: cx.round(2), y2: yl.round(2),
        stroke: wick, "stroke-width": 1
      )
      parts << tag.rect(
        x: (cx - body_w / 2.0).round(2),
        y: y_top.round(2),
        width: body_w.round(2),
        height: body_h.round(2),
        fill: col
      )
    end

    tag.svg(
      class: "terminal-quote-chart-svg terminal-quote-chart-svg--candles",
      viewBox: "0 0 #{w} #{h}",
      preserveAspectRatio: "xMidYMid meet"
    ) do
      safe_join(parts)
    end
  end

  private

  # Maps a price to SVG y inside the plot (higher price = smaller y).
  def candle_y(price, min_v, range, plot_h, top_pad)
    top_pad + plot_h - ((price - min_v) / range) * plot_h
  end
end
