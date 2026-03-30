class StockPriceService
  def initialize(client: ApiClients::YahooFinanceClient.new)
    @client = client
  end

  def search(query)
    @client.search(query)
  end

  def get_price(symbol)
    quote = @client.quote(symbol)
    return nil unless quote

    StockPrice.upsert(
      {
        symbol: quote[:symbol].to_s.upcase,
        price: quote[:price],
        updated_at: Time.current
      },
      unique_by: :index_stock_prices_on_symbol
    )

    quote
  rescue StandardError => e
    Rails.logger.warn("Stock price fetch failed for #{symbol}: #{e.class} #{e.message}")
    nil
  end
end
