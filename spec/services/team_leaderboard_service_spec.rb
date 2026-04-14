require "rails_helper"

RSpec.describe TeamLeaderboardService do
  describe "#compute" do
    it "ranks eligible teams before ineligible ones and builds a fallback trend for empty teams" do
      league = create(
        :league,
        starting_capital: 100_000,
        team_mode: true,
        team_min_participants: 2,
        team_max_participants: 4,
        start_date: 2.weeks.ago,
        end_date: 1.week.from_now
      )

      winning_team = Team.create!(league:, name: "Winners", password: "Secret123!", password_confirmation: "Secret123!")
      runner_team = Team.create!(league:, name: "Runners Up", password: "Secret123!", password_confirmation: "Secret123!")
      empty_team = Team.create!(league:, name: "Empty Team", password: "Secret123!", password_confirmation: "Secret123!")

      winning_user_one = create(:user, username: "winner_one")
      winning_user_two = create(:user, username: "winner_two")
      runner_user = create(:user, username: "runner_one")

      TeamMembership.create!(team: winning_team, user: winning_user_one, league:)
      TeamMembership.create!(team: winning_team, user: winning_user_two, league:)
      TeamMembership.create!(team: runner_team, user: runner_user, league:)

      create(:stock_price, symbol: "AAPL", price: 120)

      winning_portfolio_one = create(:portfolio, user: winning_user_one, league:, cash_balance: 90_000)
      winning_portfolio_two = create(:portfolio, user: winning_user_two, league:, cash_balance: 85_000)
      runner_portfolio = create(:portfolio, user: runner_user, league:, cash_balance: 20_000)

      create(:holding, portfolio: winning_portfolio_one, symbol: "AAPL", quantity: 50, average_cost: 100)
      create(:holding, portfolio: winning_portfolio_two, symbol: "AAPL", quantity: 25, average_cost: 100)

      PortfolioSnapshot.create!(portfolio: winning_portfolio_one, snapshot_date: 2.days.ago.to_date, total_value: 100_000)
      PortfolioSnapshot.create!(portfolio: winning_portfolio_two, snapshot_date: 2.days.ago.to_date, total_value: 90_000)
      PortfolioSnapshot.create!(portfolio: runner_portfolio, snapshot_date: 2.days.ago.to_date, total_value: 40_000)

      rankings = described_class.new(league).compute

      expect(rankings.map { |entry| entry[:team_id] }).to eq([ winning_team.id, runner_team.id, empty_team.id ])

      winner_entry = rankings.first
      expect(winner_entry[:eligible_for_final_ranking]).to be(true)
      expect(winner_entry[:member_count]).to eq(2)
      expect(winner_entry[:avg_portfolio_value]).to eq(92_000.0)
      expect(winner_entry[:trend].length).to be > 1

      empty_entry = rankings.last
      expect(empty_entry[:trend]).to eq([ 100_000, 0 ])
      expect(empty_entry[:eligible_for_final_ranking]).to be(false)
    end
  end
end