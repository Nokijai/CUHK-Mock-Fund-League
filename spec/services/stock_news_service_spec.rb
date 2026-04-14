require "rails_helper"

RSpec.describe StockNewsService do
  let(:cache) { double("cache") }

  before do
    allow(cache).to receive(:fetch) { |_key, expires_in:, &block| block.call }
  end

  describe "#enabled?" do
    it "returns false without an API key" do
      expect(described_class.new(api_key: nil, cache:).enabled?).to be(false)
    end
  end

  describe "#news_for" do
    it "returns an empty array for blank symbols" do
      expect(described_class.new(api_key: "token", cache:).news_for(" ")).to eq([])
    end

    it "normalizes and truncates news items" do
      service = described_class.new(api_key: "token", cache:)

      allow(service).to receive(:fetch_company_news).and_return(
        Array.new(13) do |index|
          {
            "headline" => "Headline #{index}",
            "url" => "https://example.com/#{index}",
            "source" => "Reuters",
            "datetime" => 1_700_000_000 + index,
            "summary" => "Summary #{index}"
          }
        end
      )

      news = service.news_for("aapl")

      expect(news.length).to eq(12)
      expect(news.first).to include(
        headline: "Headline 0",
        url: "https://example.com/0",
        source: "Reuters",
        summary: "Summary 0"
      )
      expect(news.first[:published_at]).to be_a(Time)
    end

    it "returns an empty array when fetching fails" do
      service = described_class.new(api_key: "token", cache:)
      allow(service).to receive(:fetch_company_news).and_raise(JSON::ParserError.new("bad json"))

      expect(service.news_for("aapl")).to eq([])
    end
  end

  describe "#published_at_from" do
    it "returns nil when Time.at raises a range error" do
      service = described_class.new(api_key: "token", cache:)

      expect(service.send(:published_at_from, nil)).to be_nil
      allow(Time).to receive(:at).and_raise(RangeError.new("too large"))
      expect(service.send(:published_at_from, 1_000_000_000_000)).to be_nil
    end
  end
end