class TeamLeaderboardService
  def initialize(league)
    @league = league
    @valuator = PortfolioValuationService.new
    @starting_capital = @league.starting_capital.to_f.nonzero? || 100_000.0
  end

  def compute
    teams = @league.teams.includes(users: [ portfolios: [ :holdings, :trades, :portfolio_snapshots ] ])

    portfolios = teams
      .flat_map(&:users)
      .flat_map(&:portfolios)
      .select { |p| p.league_id == @league.id }

    # Preload all symbols once to prevent per-holding quote lookups across all team members.
    @valuator.preload_symbols(portfolios.flat_map { |p| p.holdings.map(&:symbol) })

    entries = teams.map { |team| build_entry(team) }

    # Team-mode competition: rank eligible teams first, then by average balance descending.
    entries.sort_by! { |e| [ e[:eligible_for_final_ranking] ? 0 : 1, -e[:avg_portfolio_value] ] }

    entries.each_with_index do |e, i|
      e[:rank] = i + 1
    end

    entries
  end

  private

  def build_entry(team)
    portfolios = team.users.flat_map(&:portfolios).select { |p| p.league_id == @league.id }

    member_values = portfolios.map { |p| portfolio_total_value(p) }
    avg_value = member_values.any? ? (member_values.sum / member_values.size) : 0.0
    return_pct = @starting_capital.positive? ? ((avg_value - @starting_capital) / @starting_capital * 100.0) : 0.0

    eligible_for_final_ranking = @league.team_eligible?(team)

    {
      team_id: team.id,
      team_name: team.name,
      member_count: team.team_memberships_count.to_i,
      eligible_for_final_ranking: eligible_for_final_ranking,
      avg_portfolio_value: avg_value.round(2),
      avg_return_pct: return_pct.round(2),
      trend: build_team_trend(portfolios, avg_value)
    }
  end

  def portfolio_total_value(portfolio)
    holdings_value = @valuator.holdings_market_value(portfolio).to_f
    portfolio.cash_balance.to_f + holdings_value
  end

  # Build a simple team sparkline as an averaged curve of member snapshot series.
  # We align series by index (oldest-to-newest within the truncated window) and average available points.
  def build_team_trend(portfolios, current_avg_value)
    series = portfolios.map do |p|
      snapshots = p.portfolio_snapshots.ordered.to_a
      values = snapshots.last(29).map { |s| s.total_value.to_f.round(0) }
      values << portfolio_total_value(p).round(0)
      values.unshift(@starting_capital.round(0)) if values.size < 2
      values
    end

    return [ @starting_capital.round(0), current_avg_value.round(0) ] if series.empty?

    max_len = series.map(&:size).max.to_i
    averaged = (0...max_len).map do |idx|
      points = series.filter_map { |arr| arr[idx] }
      points.any? ? (points.sum / points.size).round(0) : @starting_capital.round(0)
    end

    averaged = [ @starting_capital.round(0), current_avg_value.round(0) ] if averaged.size < 2
    averaged
  end
end
