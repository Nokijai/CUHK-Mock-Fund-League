require "json"
require "open3"
require "time"

module MarketData
  class YfinanceMarketDataService
    # We call a small Python yfinance wrapper so we can keep the Rails app's
    # request path fully DB-backed (no external API calls on user requests).
    # Matches StockCandle::INTERVALS; 15m needs a shorter lookback in yfinance (see script).
    DEFAULT_INTERVALS = %w[15m 1h 4h 1d].freeze

    def fetch_symbol(symbol, intervals: DEFAULT_INTERVALS)
      sym = symbol.to_s.upcase
      ivs = Array(intervals).map(&:to_s)

      stdout, stderr, status = Open3.capture3(
        python_command,
        Rails.root.join("scripts/yfinance_fetch.py").to_s,
        "--symbol",
        sym,
        "--intervals",
        ivs.join(",")
      )

      raise "yfinance fetch failed for #{sym}: #{stderr.presence || stdout}" unless status.success?

      JSON.parse(stdout)
    rescue JSON::ParserError => e
      raise "yfinance fetch returned invalid JSON for #{sym}: #{e.message}"
    end

    private

    # Use `python` by default because some Conda envs expose yfinance there while
    # `python3` may still resolve to system/Homebrew Python on PATH.
    # Allow override via env var for deployment/runtime flexibility.
    def python_command
      ENV.fetch("MARKET_DATA_PYTHON_BIN", "python")
    end
  end
end
