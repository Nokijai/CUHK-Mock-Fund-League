require "rails_helper"

RSpec.describe StockPrice, type: :model do
  describe ".matching_query" do
    it "finds symbols by a case-insensitive substring" do
      aapl = create(:stock_price, symbol: "AAPL", price: 100)
      create(:stock_price, symbol: "MSFT", price: 200)

      expect(described_class.matching_query("aap")).to contain_exactly(aapl)
    end

    it "supports spaced tokens in the search string" do
      spaced = create(:stock_price, symbol: "BRK B", price: 300)
      create(:stock_price, symbol: "TSLA", price: 400)

      expect(described_class.matching_query("brk b")).to contain_exactly(spaced)
    end
  end
end
