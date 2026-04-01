class LeaderboardUpdateJob < ApplicationJob
  queue_as :default

  def perform(league_id)
    league = League.find_by(id: league_id)
    return unless league

    PortfolioSnapshotService.new.take_league_snapshots(league)

    rankings = LeaderboardService.new(league).compute

    rankings.each do |entry|
      portfolio = Portfolio.find_by(id: entry[:portfolio_id])
      next unless portfolio

      current_rank = entry[:rank]
      if portfolio.best_rank.nil? || current_rank < portfolio.best_rank
        portfolio.update_column(:best_rank, current_rank)
      end
    end
  end
end
