require "rails_helper"
require "nokogiri"

RSpec.describe "Trades", type: :request do
  let(:user) { create(:user, username: "demo_trader") }
  let(:league) { create(:league, start_date: 1.day.ago, end_date: 1.day.from_now) }
  let(:portfolio) { create(:portfolio, user: user, league: league) }
  let!(:membership) { create(:league_membership, user: user, league: league) }

  before do
    # Trading pages are protected by Devise.
    sign_in user
  end

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

    it "prefills sell side from query params" do
      get new_portfolio_trade_path(portfolio, prefill_symbol: "AAPL", prefill_trade_type: "sell")
      doc = Nokogiri::HTML(response.body)
      side_el = doc.at_css("#trade_trade_type")
      selected = side_el&.at_css("option[selected]")
      expect(selected&.[]("value")).to eq("sell")
    end

    it "shows league positions summary when portfolio has holdings" do
      create(:holding, portfolio: portfolio)

      get new_portfolio_trade_path(portfolio, league_id: portfolio.league_id)
      expect(response.body).to include("YOUR POSITIONS IN THIS LEAGUE")
      expect(response.body).to include("AAPL")
    end

    it "renders one row per market day for 1d historical prices" do
      # Two 1d rows on the same NY market day should collapse to one display row.
      create(
        :stock_price,
        symbol: "AMR",
        price: 209.31
      )
      StockCandle.create!(
        symbol: "AMR",
        interval: "1d",
        candle_at: Time.find_zone("UTC").parse("2026-04-02 04:00:00"),
        open: 197.46,
        high: 209.63,
        low: 197.46,
        close: 209.31,
        volume: 206_200
      )
      StockCandle.create!(
        symbol: "AMR",
        interval: "1d",
        candle_at: Time.find_zone("UTC").parse("2026-04-02 12:00:00"),
        open: 197.46,
        high: 209.63,
        low: 197.46,
        close: 209.31,
        volume: 206_200
      )

      get new_portfolio_trade_path(portfolio, q: "AMR", quote_interval: "1d")
      expect(response).to have_http_status(:ok)

      doc = Nokogiri::HTML(response.body)
      rows = doc.css(".terminal-historical-prices tbody tr")

      expect(rows.length).to eq(1)
    end
  end

  describe "GET /portfolios/:portfolio_id/trades/new for a future league" do
    let(:future_league) { create(:league, start_date: 1.day.from_now, end_date: 1.month.from_now) }
    let(:future_portfolio) { create(:portfolio, user: user, league: future_league) }
    let!(:future_membership) { create(:league_membership, user: user, league: future_league) }

    before do
      membership.destroy
      portfolio.destroy
    end

    it "redirects to leagues" do
      get new_portfolio_trade_path(future_portfolio)
      expect(response).to redirect_to(leagues_path)
    end
  end
end
