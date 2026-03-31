require "rails_helper"

RSpec.describe "Leaderboards", type: :request do
  let(:league) { create(:league) }
  let(:user) { create(:user) }
  let!(:portfolio) { create(:portfolio, user: user, league: league, cash_balance: 50_000) }

  describe "GET /leagues/:league_id/leaderboard" do
    it "returns success" do
      get league_leaderboard_path(league)
      expect(response).to have_http_status(:ok)
    end

    it "shows leaderboard heading and participant" do
      get league_leaderboard_path(league)
      expect(response.body).to include("LEADERBOARD")
      expect(response.body).to include(user.name)
    end
  end
end
