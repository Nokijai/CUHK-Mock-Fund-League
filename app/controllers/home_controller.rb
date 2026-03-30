class HomeController < ApplicationController
  def dashboard
    @portfolio = demo_focus_portfolio
    @league = @portfolio&.league || League.order(:id).first
    valuator = PortfolioValuationService.new
    @total_value = @portfolio ? valuator.total_value(@portfolio).to_f : 0.0
    @cash = @portfolio&.cash_balance.to_f
    @starting = @league&.starting_capital.to_f.nonzero? || 100_000.0
    @pnl = @portfolio ? (@total_value - @starting) : 0.0
    @pnl_pct = @starting.positive? ? (@pnl / @starting * 100.0) : 0.0
    @rank = 0
    @total_participants = 0
    if @league && @portfolio
      rankings = LeaderboardService.new(@league).compute
      @total_participants = rankings.size
      idx = rankings.index { |r| r[:user_id] == @portfolio.user_id }
      @rank = idx ? idx + 1 : 0
    end
    @chart_points = chart_points(@total_value)
    @top_holdings = top_holdings_for(@portfolio, valuator)
    @market_movers = market_movers_rows
  end

  private

  def demo_focus_portfolio
    u = User.find_by(name: "Demo Trader")
    p = u&.portfolios&.first
    p || Portfolio.order(:id).first
  end

  def chart_points(end_value)
    return default_chart_points(100_000) unless end_value.positive?
    start_v = end_value * 0.93
    (0..14).map do |i|
      t = i / 14.0
      v = start_v + (end_value - start_v) * t + Math.sin(i * 0.7) * 800 + (i % 4) * 120
      { label: (Date.current - 14 + i).strftime("%b %-d"), value: v.round(2) }
    end
  end

  def default_chart_points(base)
    (0..14).map { |i| { label: (Date.current - 14 + i).strftime("%b %-d"), value: (base * (0.95 + i * 0.004)).round(2) } }
  end

  def top_holdings_for(portfolio, valuator)
    return [] unless portfolio
    portfolio.holdings.map do |h|
      last = valuator.price_for_symbol(h.symbol).to_f
      avg = h.average_cost.to_f
      mkt = last * h.quantity
      cost = avg * h.quantity
      pnl = mkt - cost
      pnl_pct = cost.positive? ? (pnl / cost * 100.0) : 0.0
      {
        symbol: h.symbol,
        qty: h.quantity,
        avg: avg,
        last: last,
        mkt: mkt,
        pnl: pnl,
        pnl_pct: pnl_pct
      }
    end.sort_by { |r| -r[:mkt] }.first(4)
  end

  MOVER_CHG = {
    "NVDA" => 2.31, "AAPL" => 1.15, "MSFT" => -0.42, "GOOGL" => 0.88, "0700" => -1.05, "META" => 0.55
  }.freeze

  MOVER_LABELS = {
    "NVDA" => "NVIDIA Corp", "AAPL" => "Apple Inc", "MSFT" => "Microsoft", "GOOGL" => "Alphabet",
    "0700" => "Tencent", "META" => "Meta Platforms"
  }.freeze

  def market_movers_rows
    %w[NVDA AAPL MSFT GOOGL 0700].filter_map do |sym|
      sp = StockPrice.find_by(symbol: sym)
      next unless sp
      {
        symbol: sym,
        name: MOVER_LABELS[sym] || sym,
        price: sp.price.to_f,
        chg: MOVER_CHG[sym] || 0.0
      }
    end
  end
end
