require "rails_helper"

RSpec.describe LeaderboardUpdateJob, type: :job do
  describe "#perform" do
    it "returns early when league does not exist" do
      expect(PortfolioSnapshotService).not_to receive(:new)
      expect(LeaderboardService).not_to receive(:new)

      described_class.perform_now(-1)
    end

    it "takes snapshots and updates improved best ranks" do
      league = create(:league)
      portfolio_a = create(:portfolio, league: league, best_rank: nil)
      portfolio_b = create(:portfolio, league: league, best_rank: 1)

      rankings = [
        { portfolio_id: portfolio_a.id, rank: 2 },
        { portfolio_id: portfolio_b.id, rank: 3 },
        { portfolio_id: 999_999, rank: 1 }
      ]

      snapshot_service = instance_double(PortfolioSnapshotService)
      leaderboard_service = instance_double(LeaderboardService, compute: rankings)

      allow(PortfolioSnapshotService).to receive(:new).and_return(snapshot_service)
      allow(LeaderboardService).to receive(:new).with(league).and_return(leaderboard_service)
      allow(snapshot_service).to receive(:take_league_snapshots)

      described_class.perform_now(league.id)

      expect(snapshot_service).to have_received(:take_league_snapshots).with(league)
      expect(portfolio_a.reload.best_rank).to eq(2)
      expect(portfolio_b.reload.best_rank).to eq(1)
    end
  end
end
