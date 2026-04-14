require "rails_helper"

RSpec.describe "Leaderboards", type: :request do
  let(:league) { create(:league, start_date: 1.day.ago, end_date: 1.day.from_now) }
  let(:user) { create(:user) }
  # Leaderboard HTML is behind the same joined-league gate as the rest of the app.
  let!(:membership) { create(:league_membership, user: user, league: league) }
  let!(:portfolio) { create(:portfolio, user: user, league: league, cash_balance: 50_000) }

  before do
    # Views under ApplicationController require a signed-in user.
    sign_in user
  end

  describe "GET /leagues/:league_id/leaderboard" do
    it "returns success" do
      get league_leaderboard_path(league)
      expect(response).to have_http_status(:ok)
    end

    it "shows leaderboard heading and participant" do
      get league_leaderboard_path(league)
      expect(response.body).to include("LEADERBOARD")
      expect(response.body).to include(user.username)
    end

    it "redirects when the league has not started yet" do
      future_league = create(:league, start_date: 1.day.from_now, end_date: 1.month.from_now)

      get league_leaderboard_path(future_league)
      expect(response).to redirect_to(leagues_path(anchor: "league-#{future_league.id}"))
    end

    it "allows viewing leaderboard for a past league" do
      past_league = create(:league, start_date: 2.months.ago, end_date: 1.month.ago)
      create(:portfolio, user: user, league: past_league, cash_balance: 50_000)

      get league_leaderboard_path(past_league)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("LEADERBOARD")
    end
  end
end
