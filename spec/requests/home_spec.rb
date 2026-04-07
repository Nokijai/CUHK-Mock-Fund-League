require "rails_helper"

RSpec.describe "Home dashboard", type: :request do
  let(:user) { create(:user) }

  before do
    # Dashboard is behind authentication.
    sign_in user
  end

  describe "GET /" do
    it "returns success" do
      get root_path
      expect(response).to have_http_status(:ok)
    end

    it "renders dashboard metrics" do
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
