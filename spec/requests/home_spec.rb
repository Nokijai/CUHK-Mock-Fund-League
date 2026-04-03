require "rails_helper"

RSpec.describe "Home dashboard", type: :request do
  let(:league) { create(:league, starting_capital: 100_000) }
  let(:user) { create(:user, name: "Demo Trader", email: "demo@example.com", password: "Demo123!", password_confirmation: "Demo123!") }
  let(:portfolio) { create(:portfolio, user: user, league: league, cash_balance: 22_000, total_value: 121_700) }

  before do
    create(:stock_price, symbol: "AAPL", price: 188.75)
    create(:stock_price, symbol: "NVDA", price: 875.20)
    create(:stock_price, symbol: "MSFT", price: 421.30)
    create(:stock_price, symbol: "GOOGL", price: 168.10)
    create(:stock_price, symbol: "META", price: 515.40)
    create(:stock_price, symbol: "0700", price: 402.75)

    create(:holding, portfolio: portfolio, symbol: "AAPL", quantity: 250, average_cost: 156.0)
    create(:holding, portfolio: portfolio, symbol: "NVDA", quantity: 60, average_cost: 650.0)

    create(:trade, portfolio: portfolio, symbol: "AAPL", trade_type: "buy", quantity: 150, price: 150.0, executed_at: 12.days.ago)
    create(:trade, portfolio: portfolio, symbol: "AAPL", trade_type: "buy", quantity: 100, price: 165.0, executed_at: 8.days.ago)
    create(:trade, portfolio: portfolio, symbol: "NVDA", trade_type: "buy", quantity: 60, price: 650.0, executed_at: 2.days.ago)

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
