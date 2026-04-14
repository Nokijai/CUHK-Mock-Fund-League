require "rails_helper"

RSpec.describe LeaderboardService do
  describe "#compute" do
    it "ranks eligible portfolios ahead of ineligible ones and calculates performance metrics" do
      league = create(
        :league,
        starting_capital: 100_000,
        minimum_final_balance: 90_000,
        start_date: 2.weeks.ago,
        end_date: 1.week.from_now
      )

      winning_user = create(:user, username: "winner")
      trailing_user = create(:user, username: "trailer")
      winning_portfolio = create(:portfolio, user: winning_user, league:, cash_balance: 90_000, best_rank: 4)
      trailing_portfolio = create(:portfolio, user: trailing_user, league:, cash_balance: 20_000, best_rank: nil)

      create(:stock_price, symbol: "AAPL", price: 110)
      create(:holding, portfolio: winning_portfolio, symbol: "AAPL", quantity: 50, average_cost: 100)
      create(:trade, portfolio: winning_portfolio, symbol: "AAPL", trade_type: "buy", order_type: "market", quantity: 10, price: 100)
      StockPrice.find_by!(symbol: "AAPL").update!(price: 120)
      create(:trade, portfolio: winning_portfolio, symbol: "AAPL", trade_type: "sell", order_type: "market", quantity: 5, price: 120)

      PortfolioSnapshot.create!(portfolio: winning_portfolio, snapshot_date: 2.days.ago.to_date, total_value: 100_000)
      PortfolioSnapshot.create!(portfolio: winning_portfolio, snapshot_date: 1.day.ago.to_date, total_value: 90_000)

      PortfolioSnapshot.create!(portfolio: trailing_portfolio, snapshot_date: 2.days.ago.to_date, total_value: 50_000)

      rankings = described_class.new(league).compute

      expect(rankings.map { |entry| entry[:user_id] }).to eq([ winning_user.id, trailing_user.id ])

      leader = rankings.first
      expect(leader[:rank]).to eq(1)
      expect(leader[:eligible_for_final_ranking]).to be(true)
      expect(leader[:portfolio_value]).to eq(96_100.0)
      expect(leader[:total_return_pct]).to eq(-3.9)
      expect(leader[:daily_change_pct]).to eq(6.78)
      expect(leader[:max_drawdown_pct]).to eq(-10.0)
      expect(leader[:win_rate]).to eq(100.0)
      expect(leader[:trade_count]).to eq(2)
      expect(leader[:highest_rank]).to eq(1)
      expect(leader[:trend]).to eq([ 100_000, 90_000, 96_100 ])

      trailer = rankings.last
      expect(trailer[:eligible_for_final_ranking]).to be(false)
      expect(trailer[:rank]).to eq(2)
      expect(trailer[:highest_rank]).to eq(2)
      expect(trailer[:trend]).to eq([ 50_000, 20_000 ])
    end
  end
end
