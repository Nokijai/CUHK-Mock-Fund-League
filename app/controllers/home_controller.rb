class HomeController < ApplicationController
  def dashboard
    @portfolio = dashboard_portfolio
    @league = dashboard_league(@portfolio)
    valuator = PortfolioValuationService.new
    @total_value = @portfolio ? valuator.total_value(@portfolio).to_f : 0.0
    @cash = @portfolio&.cash_balance.to_f
    @starting = @league&.starting_capital.to_f.nonzero? || 100_000.0
    @pnl = @portfolio ? (@total_value - @starting) : 0.0
    @pnl_pct = @starting.positive? ? (@pnl / @starting * 100.0) : 0.0
    @rank, @total_participants = dashboard_rank(@league, @portfolio)
    @chart_points = portfolio_performance_points(@portfolio, valuator)
    @top_holdings = top_holdings_for(@portfolio, valuator)
    @market_movers = market_movers_rows
  end

  private

  def dashboard_portfolio
    current_user&.portfolios&.includes(:league, :holdings, :trades)&.order(updated_at: :desc)&.first || demo_focus_portfolio
  end

  def dashboard_league(portfolio)
    portfolio&.league || current_user&.leagues&.order(:id)&.first || League.order(:id).first
  end

  def dashboard_rank(league, portfolio)
    return [ 0, 0 ] unless league && portfolio

    rankings = LeaderboardService.new(league).compute
    index = rankings.index { |row| row[:user_id] == portfolio.user_id }
    [ index ? index + 1 : 0, rankings.size ]
  end

  def portfolio_performance_points(portfolio, valuator)
    return default_chart_points(@starting) unless portfolio

    trades = portfolio.trades.order(Arel.sql("COALESCE(executed_at, created_at) ASC"), :id).to_a
    return default_chart_points(@total_value.positive? ? @total_value : @starting) if trades.empty?

    (Date.current - 14..Date.current).map do |date|
      snapshot = portfolio_snapshot_at(portfolio, trades, date.end_of_day)
      value = snapshot[:cash] + holdings_market_value_from_positions(snapshot[:positions], valuator)
      { label: date.strftime("%b %-d"), value: value.round(2) }
    end
  end

  def default_chart_points(base)
    (0..14).map { |i| { label: (Date.current - 14 + i).strftime("%b %-d"), value: (base * (0.95 + i * 0.004)).round(2) } }
  end

  def portfolio_snapshot_at(portfolio, trades, cutoff_time)
    cash = portfolio.league&.starting_capital.to_d
    cash = 100_000.to_d if cash <= 0
    positions = Hash.new(0)

    trades.each do |trade|
      trade_time = trade.executed_at || trade.created_at
      next if trade_time > cutoff_time

      trade_value = trade.price.to_d * trade.quantity.to_d
      if trade.trade_type.to_s.downcase == "sell"
        cash += trade_value
        positions[trade.symbol] -= trade.quantity.to_i
      else
        cash -= trade_value
        positions[trade.symbol] += trade.quantity.to_i
      end
    end

    { cash: cash, positions: positions }
  end

  def holdings_market_value_from_positions(positions, valuator)
    positions.sum do |symbol, quantity|
      next 0.to_d if quantity.to_i <= 0

      valuator.price_for_symbol(symbol) * quantity.to_i
    end
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
    symbols = (StockPrice.order(:symbol).pluck(:symbol) + Trade.order(updated_at: :desc, created_at: :desc).limit(20).pluck(:symbol)).uniq

    symbols.filter_map do |sym|
      sp = StockPrice.find_by(symbol: sym)
      next unless sp

      trade_prices = Trade.where(symbol: sym).order(Arel.sql("COALESCE(executed_at, created_at) ASC"), :id).pluck(:price)
      chg = if trade_prices.size >= 2
        base = trade_prices.first.to_f
        base.positive? ? ((sp.price.to_f - base) / base * 100.0) : 0.0
      elsif trade_prices.size == 1
        base = trade_prices.first.to_f
        base.positive? ? ((sp.price.to_f - base) / base * 100.0) : 0.0
      else
        0.0
      end

      {
        symbol: sym,
        name: MOVER_LABELS[sym] || sym,
        price: sp.price.to_f,
        chg: chg
      }
    end.sort_by { |row| -row[:chg].abs }.first(5)
  end

  def demo_focus_portfolio
    user = User.find_by(name: "Demo Trader")
    user&.portfolios&.includes(:league, :holdings, :trades)&.first || Portfolio.order(:id).first
  end

  def mover_name(symbol)
    MOVER_LABELS[symbol] || symbol
  end
end
