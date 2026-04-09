class HomeController < ApplicationController
  def dashboard
    @portfolio = current_user_focus_portfolio
    @league = @portfolio&.league || @selected_league
    valuator = PortfolioValuationService.new
    # Warm quote cache once for all dashboard widgets (holdings, movers, ticker).
    valuator.preload_symbols(dashboard_quote_symbols)
    @total_value = @portfolio ? valuator.total_value(@portfolio).to_f : 0.0
    @cash = @portfolio&.cash_balance.to_f
    @starting = @league&.starting_capital.to_f.nonzero? || 100_000.0
    @pnl = @portfolio ? (@total_value - @starting) : 0.0
    @pnl_pct = @starting.positive? ? (@pnl / @starting * 100.0) : 0.0
    # Lightweight rank lookup — avoids computing full leaderboard with trades/snapshots
    # just to display one number on the dashboard.
    rank_info = @league && @portfolio ? lightweight_rank(@league, @portfolio) : { rank: 0, total: 0 }
    @rank = rank_info[:rank]
    @total_participants = rank_info[:total]
    @chart_points = portfolio_performance_points(@portfolio, valuator)
    @top_holdings = top_holdings_for(@portfolio, valuator)
    @market_movers = cached_market_movers
    # Separate horizontal tickers: tracked stocks vs browseable leagues (not one merged strip).
    @ticker_stock_items = cached_ticker_stock_items
    @ticker_league_items = cached_ticker_league_items
  end

  # Handles GET /trading (nav link, bookmarks, SW). Resolves portfolio on the server so
  # the header does not need a separate nav_p check that could disagree with the DB.
  def trading_redirect
    portfolio = current_user_focus_portfolio
    if portfolio
      redirect_to new_portfolio_trade_path(portfolio, league_id: portfolio.league_id), status: :see_other
    else
      redirect_to leagues_path, status: :see_other
    end
  end

  private

  # Resolves the current user's portfolio in the selected league (fallback = first owned portfolio).
  def current_user_focus_portfolio
    return nil unless current_user
    return @league_portfolio_map[@selected_league.id] if @selected_league

    current_user.portfolios.first
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

  def market_movers_rows
    # Surface a slice of the Nestak watchlist; prices come from DB (refreshed by jobs).
    symbols = MarketData::NestakTop30::SYMBOLS.first(6)
    prices_by_symbol = stock_prices_for(symbols)

    symbols.filter_map do |sym|
      sp = prices_by_symbol[sym]
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
        name: MarketData::NestakTop30::DISPLAY_NAMES[sym] || sym,
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

  # Stock-only row hashes for the first dashboard marquee bar.
  def ticker_stock_items_rows
    scrolling_stocks_rows.map do |row|
      {
        symbol: row[:symbol],
        name: row[:name],
        price: row[:price]
      }
    end
  end

  # League-only row hashes for the second dashboard marquee bar.
  def ticker_league_items_rows
    available_league_rows.map do |row|
      {
        id: row[:id],
        name: row[:name],
        members_count: row[:members_count],
        starting_capital: row[:starting_capital]
      }
    end
  end

  # Pulls DB-backed prices for the tracked symbols so the ticker stays request-local.
  def scrolling_stocks_rows
    symbols = MarketData::NestakTop30::ALL_REFRESH_SYMBOLS
    prices_by_symbol = stock_prices_for(symbols)

    symbols.filter_map do |sym|
      stock_price = prices_by_symbol[sym]
      next unless stock_price

      {
        symbol: sym,
        name: MarketData::NestakTop30::DISPLAY_NAMES[sym] || sym,
        price: stock_price.price.to_f
      }
    end
  end

  # Lists leagues users can browse/join with a compact set of fields for the ticker.
  def available_league_rows
    # Counter in SQL avoids loading all membership rows just to count.
    League
      .left_joins(:league_memberships)
      .group("leagues.id")
      .order(start_date: :asc)
      .limit(10)
      .pluck("leagues.id", "leagues.name", "leagues.starting_capital", "COUNT(league_memberships.id)")
      .map do |id, name, starting_capital, members_count|
      {
        id: id,
        name: name,
        members_count: members_count.to_i,
        starting_capital: starting_capital.to_f
      }
    end
  end

  # Computes only the current user's rank without loading trades/snapshots/sparklines
  # for every portfolio in the league (the full LeaderboardService is 10-50x heavier).
  def lightweight_rank(league, portfolio)
    valuator = PortfolioValuationService.new
    portfolios = league.portfolios.includes(:holdings).to_a

    all_symbols = portfolios.flat_map { |p| p.holdings.map(&:symbol) }.uniq
    valuator.preload_symbols(all_symbols)

    values = portfolios.map do |p|
      { portfolio_id: p.id, value: p.cash_balance.to_f + valuator.holdings_market_value(p).to_f }
    end

    values.sort_by! { |v| -v[:value] }
    idx = values.index { |v| v[:portfolio_id] == portfolio.id }

    { rank: idx ? idx + 1 : 0, total: values.size }
  end

  # Cached stock strip; prices follow market job cadence.
  def cached_ticker_stock_items
    Rails.cache.fetch("dashboard/ticker_stock_items", expires_in: 2.minutes) do
      ticker_stock_items_rows
    end
  end

  # Cached league strip; membership counts change less often but still bounded TTL.
  def cached_ticker_league_items
    Rails.cache.fetch("dashboard/ticker_league_items", expires_in: 2.minutes) do
      ticker_league_items_rows
    end
  end

  # Cache wrapper for market movers section.
  def cached_market_movers
    Rails.cache.fetch("dashboard/market_movers", expires_in: 2.minutes) do
      market_movers_rows
    end
  end

  # One symbol list for dashboard quote consumers to keep DB access batched.
  def dashboard_quote_symbols
    symbols = MarketData::NestakTop30::ALL_REFRESH_SYMBOLS.dup
    symbols.concat(MarketData::NestakTop30::SYMBOLS.first(6))
    symbols.concat(@portfolio&.holdings&.map(&:symbol) || [])
    symbols.map { |s| s.to_s.upcase }.uniq
  end

  # Centralized quote lookup to avoid repeated where/find_by calls.
  def stock_prices_for(symbols)
    @stock_prices_cache ||= {}
    normalized = Array(symbols).map { |s| s.to_s.upcase }.uniq
    missing = normalized.reject { |sym| @stock_prices_cache.key?(sym) }

    if missing.any?
      StockPrice.where(symbol: missing).find_each do |row|
        @stock_prices_cache[row.symbol] = row
      end
      # Mark misses so repeated calls do not keep querying absent symbols.
      missing.each { |sym| @stock_prices_cache[sym] ||= nil }
    end

    @stock_prices_cache.slice(*normalized)
  end
end
