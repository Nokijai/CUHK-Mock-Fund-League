require "rails_helper"

RSpec.describe "Api::V1::Trades", type: :request do
  let(:headers) { { "Content-Type" => "application/json", "Accept" => "application/json" } }
  let(:current_user) { create(:user) }

  before do
    # Keep API auth behavior aligned with other request specs in this project.
    sign_in current_user
  end

  describe "POST /api/v1/portfolios/:portfolio_id/trades" do
    let!(:portfolio) { create(:portfolio, user: current_user, cash_balance: 100_000, total_value: 100_000) }

    before do
      create(:stock_price, symbol: "AAPL", price: 150.0)
    end

    it "creates a trade with portfolio id from route path" do
      payload = {
        trade: {
          symbol: "aapl",
          trade_type: "buy",
          order_type: "market",
          quantity: 5
        }
      }.to_json

      expect {
        post "/api/v1/portfolios/#{portfolio.id}/trades", params: payload, headers: headers
      }.to change(Trade, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["portfolio_id"]).to eq(portfolio.id)
      expect(json["symbol"]).to eq("AAPL")
    end

    it "does not accept invalid order payloads" do
      payload = {
        trade: {
          symbol: "AAPL",
          trade_type: "buy",
          order_type: "market",
          quantity: 0
        }
      }.to_json

      post "/api/v1/portfolios/#{portfolio.id}/trades", params: payload, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to be_present
    end
  end
end
