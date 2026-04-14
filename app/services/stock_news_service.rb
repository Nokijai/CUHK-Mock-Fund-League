require "net/http"
require "json"

class StockNewsService
  # Lightweight wrapper around an external financial news API.
  #
  # Provider choice: Finnhub's `company-news` endpoint is simple and ticker-based.
  # We cache results in Rails.cache to avoid burning quota and to keep page loads fast.

  FINNHUB_BASE_URL = "https://finnhub.io/api/v1"
  CACHE_TTL = 10.minutes
  DEFAULT_LOOKBACK_DAYS = 7
  MAX_ITEMS = 12

  def initialize(api_key: ENV.fetch("FINNHUB_API_KEY", nil), cache: Rails.cache)
    @api_key = api_key
    @cache = cache
  end

  def enabled?
    @api_key.present?
  end

  # Returns an array of normalized news hashes:
  # { headline:, url:, source:, published_at:, summary: }
  def news_for(symbol, from: DEFAULT_LOOKBACK_DAYS.days.ago.to_date, to: Date.current)
    sym = symbol.to_s.upcase
    return [] if sym.blank?
    return [] unless enabled?

    cache_key = "stock-news:v1:#{sym}:#{from}:#{to}"

    @cache.fetch(cache_key, expires_in: CACHE_TTL) do
      raw = fetch_company_news(sym, from:, to:)
      normalize(raw).first(MAX_ITEMS)
    end
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    Rails.logger.info("[stock-news] #{sym} fetch failed: #{e.class}: #{e.message}")
    []
  end

  private

  def fetch_company_news(symbol, from:, to:)
    uri = URI("#{FINNHUB_BASE_URL}/company-news")
    uri.query = URI.encode_www_form(
      symbol: symbol,
      from: from.to_s,
      to: to.to_s,
      token: @api_key
    )

    req = Net::HTTP::Get.new(uri)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 8) do |http|
      res = http.request(req)
      return [] unless res.is_a?(Net::HTTPSuccess)
      JSON.parse(res.body)
    end
  end

  def normalize(items)
    Array(items).filter_map do |i|
      url = i["url"].to_s
      headline = i["headline"].to_s
      next if url.blank? || headline.blank?

      {
        headline: headline,
        url: url,
        source: i["source"].to_s.presence,
        published_at: published_at_from(i["datetime"]),
        summary: i["summary"].to_s.presence
      }
    end
  end

  def published_at_from(epoch_seconds)
    return nil if epoch_seconds.blank?
    Time.at(epoch_seconds.to_i).in_time_zone
  rescue RangeError
    nil
  end
end
