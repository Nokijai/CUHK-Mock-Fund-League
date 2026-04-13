require "rails_helper"

RSpec.describe "Api::V1::Stocks", type: :request do
  let(:headers) { { "Content-Type" => "application/json", "Accept" => "application/json" } }
  let(:current_user) { create(:user) }

  before do
    # Keep API auth behavior aligned with other request specs in this project.
    sign_in current_user
  end

  describe "GET /api/v1/stocks/:symbol" do
    it "returns latest stock payload for a symbol" do
      create(:stock_price, symbol: "NVDA", price: 123.45)

      get "/api/v1/stocks/nvda", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["symbol"]).to eq("NVDA")
      expect(json["price"]).to eq(123.45)
    end

    it "includes candles when interval is requested" do
      create(:stock_price, symbol: "NVDA", price: 123.45)
      StockCandle.create!(
        symbol: "NVDA",
        interval: "1h",
        candle_at: 1.hour.ago,
        open: 120.0,
        high: 125.0,
        low: 119.5,
        close: 123.45,
        volume: 1000
      )

      get "/api/v1/stocks/NVDA", params: { interval: "1h", limit: 5 }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["interval"]).to eq("1h")
      expect(json["candles"]).to be_an(Array)
      expect(json["candles"].first.keys).to include("t", "o", "h", "l", "c", "v")
    end

    it "returns not found when stock symbol does not exist" do
      get "/api/v1/stocks/UNKNOWN", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
