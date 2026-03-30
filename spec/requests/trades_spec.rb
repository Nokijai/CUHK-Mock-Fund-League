require "rails_helper"
require "nokogiri"

RSpec.describe "Trades", type: :request do
  let(:user) { create(:user, name: "Demo Trader") }
  let(:league) { create(:league) }
  let(:portfolio) { create(:portfolio, user: user, league: league) }

  describe "GET /portfolios/:portfolio_id/trades/new" do
    before do
      create(:stock_price, symbol: "AAPL", price: 189.23)
      create(:stock_price, symbol: "MSFT", price: 378.50)
    end

    it "returns success" do
      get new_portfolio_trade_path(portfolio)
      expect(response).to have_http_status(:ok)
    end

    it "lists available stocks for trading" do
      get new_portfolio_trade_path(portfolio)
      expect(response.body).to include("AVAILABLE STOCKS")
      expect(response.body).to include("AAPL")
      expect(response.body).to include("MSFT")
    end

    it "prefills symbol and price from query params" do
      get new_portfolio_trade_path(portfolio, prefill_symbol: "msft", prefill_price: "378.5")
      doc = Nokogiri::HTML(response.body)
      sym_el = doc.at_css("#trade_symbol")
      price_el = doc.at_css("#trade_price")
      expect(sym_el&.[]("value")).to eq("MSFT")
      expect(price_el).to be_present
      expect(BigDecimal(price_el["value"].to_s)).to eq(BigDecimal("378.5"))
    end
  end
end
