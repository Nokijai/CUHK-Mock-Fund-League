require "net/http"
require "json"

module ApiClients
  class YahooFinanceClient
    BASE_URL = "https://query1.finance.yahoo.com/v8/finance/chart/"

    def quote(symbol)
      url = URI("#{BASE_URL}#{URI.encode_www_form_component(symbol)}?interval=1d&range=1d")
      fetch_data(url, symbol)
    end

    # Get historical data for charts (range: 1d, 5d, 1mo, 3mo, 6mo, 1y)
    def history(symbol, range: "1mo", interval: "1d")
      url = URI("#{BASE_URL}#{URI.encode_www_form_component(symbol)}?interval=#{interval}&range=#{range}")

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 10

      request = Net::HTTP::Get.new(url)
      request["User-Agent"] = "Mozilla/5.0"

      response = http.request(request)
      return nil unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      result = data.dig("chart", "result", 0)
      return nil unless result

      timestamps = result["timestamp"] || []
      quotes = result.dig("indicators", "quote", 0) || {}

      timestamps.map.with_index do |ts, i|
        {
          date: Time.at(ts).to_date.to_s,
          open: quotes.dig("open", i)&.round(2),
          high: quotes.dig("high", i)&.round(2),
          low: quotes.dig("low", i)&.round(2),
          close: quotes.dig("close", i)&.round(2),
          volume: quotes.dig("volume", i)
        }
      end.compact
    rescue StandardError => e
      Rails.logger.error("Yahoo Finance history error for #{symbol}: #{e.message}")
      nil
    end

    private

    def fetch_data(url, symbol)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 10

      request = Net::HTTP::Get.new(url)
      request["User-Agent"] = "Mozilla/5.0"

      response = http.request(request)

      return nil unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      result = data.dig("chart", "result", 0)

      return nil unless result

      meta = result["meta"]
      {
        symbol: meta["symbol"],
        price: meta["regularMarketPrice"],
        previous_close: meta["previousClose"],
        currency: meta["currency"],
        exchange: meta["exchangeName"],
        updated_at: Time.at(meta["regularMarketTime"])
      }
    rescue StandardError => e
      Rails.logger.error("Yahoo Finance API error for #{symbol}: #{e.message}")
      nil
    end
  end
end
