class LeaderboardService
  def initialize(league)
    @league = league
    @valuator = PortfolioValuationService.new
    @starting_capital = @league.starting_capital.to_f.nonzero? || 100_000.0
  end

  def compute
    portfolios = @league.portfolios
      .includes(:user, :holdings, :trades, :portfolio_snapshots)
    # Preload all symbols once to prevent per-holding quote lookups per portfolio.
    @valuator.preload_symbols(portfolios.flat_map { |p| p.holdings.map(&:symbol) })

    entries = portfolios.map { |p| build_entry(p) }
    entries.sort_by! { |e| -e[:portfolio_value] }

    entries.each_with_index do |e, i|
      e[:rank] = i + 1
      stored_best = e[:highest_rank]
      e[:highest_rank] = stored_best && stored_best > 0 ? [ stored_best, i + 1 ].min : i + 1
    end

    entries
  end

  private

  def build_entry(portfolio)
    # Compute holdings value once; total value derives from cash + holdings.
    holdings_value = @valuator.holdings_market_value(portfolio).to_f
    total_value = portfolio.cash_balance.to_f + holdings_value
    cash = portfolio.cash_balance.to_f
    return_pct = @starting_capital.positive? ? ((total_value - @starting_capital) / @starting_capital * 100.0) : 0.0
    trades = portfolio.trades.to_a
    snapshots = portfolio.portfolio_snapshots.ordered.to_a

    {
      user_id: portfolio.user_id,
      portfolio_id: portfolio.id,
      name: display_name(portfolio.user),
      portfolio_value: total_value.round(2),
      total_return_pct: return_pct.round(2),
      daily_change_pct: compute_daily_change(total_value, snapshots),
      max_drawdown_pct: compute_max_drawdown(snapshots, total_value),
      win_rate: compute_win_rate(trades),
      trade_count: trades.size,
      trend: build_trend(snapshots, total_value),
      starting_balance: @starting_capital,
      current_cash: cash.round(2),
      current_equity: holdings_value.round(2),
      highest_rank: portfolio.best_rank
    }
  end

  def display_name(user)
    return "Unknown" unless user
    # Support both auth schemas: username-first, then legacy name, then email.
    (user.respond_to?(:username) ? user.username : nil).presence || user.try(:name).presence || user.email
  end

  def compute_daily_change(current_value, snapshots)
    yesterday = snapshots.select { |s| s.snapshot_date < Date.current }.last
    return 0.0 unless yesterday

    prev = yesterday.total_value.to_f
    return 0.0 unless prev.positive?
    ((current_value - prev) / prev * 100.0).round(2)
  end

  # Max peak-to-trough drawdown from snapshot history
  def compute_max_drawdown(snapshots, current_value)
    values = snapshots.map { |s| s.total_value.to_f }
    values << current_value
    return 0.0 if values.size < 2

    peak = values.first
    max_dd = 0.0
    values.each do |v|
      peak = v if v > peak
      dd = peak.positive? ? ((peak - v) / peak * 100.0) : 0.0
      max_dd = dd if dd > max_dd
    end

    -max_dd.round(2)
  end

  # Win rate = profitable sells / total sells
  def compute_win_rate(trades)
    sells = trades.select { |t| t.trade_type == "sell" }
    return 0.0 if sells.empty?

    buys_by_symbol = trades.select { |t| t.trade_type == "buy" }.group_by(&:symbol)

    wins = sells.count do |sell|
      symbol_buys = buys_by_symbol[sell.symbol] || []
      avg_buy = weighted_avg_price(symbol_buys)
      avg_buy.positive? && sell.price.to_f > avg_buy
    end

    (wins.to_f / sells.size * 100.0).round(1)
  end

  def weighted_avg_price(buy_trades)
    total_cost = buy_trades.sum { |t| t.price.to_f * t.quantity }
    total_qty = buy_trades.sum(&:quantity)
    total_qty.positive? ? total_cost / total_qty : 0.0
  end

  # Build sparkline data: last 29 snapshots + current value
  def build_trend(snapshots, current_value)
    values = snapshots.last(29).map { |s| s.total_value.to_f.round(0) }
    values << current_value.round(0)
    values.unshift(@starting_capital.round(0)) if values.size < 2
    values
  end
end
