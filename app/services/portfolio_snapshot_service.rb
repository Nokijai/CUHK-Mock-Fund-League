class PortfolioSnapshotService
  def initialize(valuator: PortfolioValuationService.new)
    @valuator = valuator
  end

  def take_snapshot(portfolio, date: Date.current)
    total = @valuator.total_value(portfolio).to_f
    holdings_val = @valuator.holdings_market_value(portfolio).to_f
    cash = portfolio.cash_balance.to_f

    PortfolioSnapshot.find_or_initialize_by(
      portfolio: portfolio,
      snapshot_date: date
    ).tap do |snap|
      snap.total_value = total
      snap.cash_balance = cash
      snap.holdings_value = holdings_val
      snap.save!
    end
  end

  def take_league_snapshots(league, date: Date.current)
    league.portfolios.find_each do |portfolio|
      take_snapshot(portfolio, date: date)
    end
  end
end
