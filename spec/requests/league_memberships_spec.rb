require "rails_helper"

RSpec.describe "League memberships (web)", type: :request do
  let(:user) { create(:user) }
  let(:league) { create(:league) }
  let!(:membership) { create(:league_membership, user: user, league: league) }

  before { sign_in user }

  describe "DELETE /league_memberships/:id" do
    it "removes membership and redirects to leagues" do
      expect {
        delete league_membership_path(membership)
      }.to change(LeagueMembership, :count).by(-1)
      expect(response).to redirect_to(leagues_path(anchor: "league-#{league.id}"))
    end

    # leave_with_cleanup! drops the league portfolio so the user can re-join with a fresh balance later.
    it "destroys the user's portfolio for that league" do
      create(:portfolio, user: user, league: league)
      expect {
        delete league_membership_path(membership)
      }.to change(Portfolio, :count).by(-1)
    end
  end
end
