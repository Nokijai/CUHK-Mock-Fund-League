require "rails_helper"

RSpec.describe "Home dashboard", type: :request do
  let(:user) { create(:user) }

  before do
    # Dashboard is behind authentication.
    sign_in user
  end

  describe "GET /" do
    # ApplicationController requires at least one LeagueMembership before non-league pages load.
    it "redirects to leagues when the user has not joined any league" do
      get root_path
      expect(response).to redirect_to(leagues_path)
    end

    it "renders dashboard metrics" do
      # Ensure the dashboard has a focus portfolio so value/cash are non-zero.
      league = create(:league)
      # Membership satisfies the joined-league gate for GET /.
      create(:league_membership, user:, league:)
      create(:portfolio, user:, league:, cash_balance: 121_699.50, total_value: 121_699.50)

      get root_path
      expect(response.body).to include("DASHBOARD")
      expect(response.body).to include("MOCK-FUND")
      expect(response.body).to include("TOTAL PORTFOLIO VALUE")
      expect(response.body).to include("CASH BALANCE")
      expect(response.body).to include("LEAGUE RANK")
      expect(response.body).to include("TOP HOLDINGS")
      expect(response.body).to include("MARKET MOVERS")
      expect(response.body).to include("$121,699.50")
    end
  end
end
