require "rails_helper"

RSpec.describe "Portfolios", type: :request do
  let(:user) { create(:user, username: "portfolio_user") }

  before do
    sign_in user
  end

  describe "GET /portfolios/:id" do
    it "returns success for a running league portfolio" do
      league = create(:league, start_date: 1.day.ago, end_date: 1.day.from_now)
      portfolio = create(:portfolio, user: user, league: league)
      create(:league_membership, user: user, league: league)

      get portfolio_path(portfolio)

      expect(response).to have_http_status(:ok)
    end

    it "redirects for a future league portfolio" do
      future_league = create(:league, start_date: 1.day.from_now, end_date: 1.month.from_now)
      future_portfolio = create(:portfolio, user: user, league: future_league)
      create(:league_membership, user: user, league: future_league)

      get portfolio_path(future_portfolio)

      expect(response).to redirect_to(leagues_path)
    end
  end
end
