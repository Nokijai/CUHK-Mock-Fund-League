module ApiClients
  class YahooFinanceClient
    BASE_URL = "https://query1.finance.yahoo.com".freeze

    require "cgi"
    require "json"
    require "net/http"
    require "uri"
    require "bigdecimal/util"

    def quote(symbol)
      return nil if symbol.to_s.strip.empty?

      payload = get_json(
        "/v8/finance/chart/#{CGI.escape(symbol.to_s.upcase)}?interval=1d&range=1d"
      )
      result = payload.dig("chart", "result")&.first
      meta = result&.dig("meta")
      return nil unless meta

      price = meta["regularMarketPrice"]
      return nil if price.nil?

      {
        symbol: meta["symbol"],
        name: meta["shortName"] || meta["longName"],
        exchange: meta["fullExchangeName"] || meta["exchangeName"],
        currency: meta["currency"],
        price: price.to_d,
        market_time: market_time_from_unix(meta["regularMarketTime"])
      }
    end

    def search(query, limit: 10)
      return [] if query.to_s.strip.empty?

      payload = get_json(
        "/v1/finance/search?q=#{CGI.escape(query)}&quotesCount=#{limit}&newsCount=0"
      )

      Array(payload["quotes"]).filter_map do |item|
        symbol = item["symbol"]
        next if symbol.to_s.strip.empty?

        {
          symbol: symbol,
          name: item["shortname"] || item["longname"] || item["symbol"],
          exchange: item["exchDisp"] || item["exchange"],
          type: item["quoteType"]
        }
      end
    rescue StandardError => e
      Rails.logger.warn("Yahoo search failed: #{e.class} #{e.message}")
      []
    end

    private

    def get_json(path)
      base_url = ENV.fetch("YAHOO_FINANCE_BASE_URL", BASE_URL)
      uri = URI("#{base_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 5

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " \
        "AppleWebKit/537.36 (KHTML, like Gecko) " \
        "Chrome/122.0.0.0 Safari/537.36"
      )
      request["Accept"] = "application/json,text/plain,*/*"
      request["Accept-Language"] = "en-US,en;q=0.9"

      response = http.request(request)
      return {} unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue StandardError => e
      Rails.logger.warn("Yahoo request failed: #{e.class} #{e.message}")
      {}
    end

    def market_time_from_unix(timestamp)
      return nil if timestamp.nil?

      Time.at(timestamp).utc
    end
  end
end
