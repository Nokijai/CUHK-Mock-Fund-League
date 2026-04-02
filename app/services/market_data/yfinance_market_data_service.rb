require "json"
require "open3"
require "time"

module MarketData
  class YfinanceMarketDataService
    # We call a small Python yfinance wrapper so we can keep the Rails app's
    # request path fully DB-backed (no external API calls on user requests).
    # Matches StockCandle::INTERVALS; 15m needs a shorter lookback in yfinance (see script).
    DEFAULT_INTERVALS = %w[15m 1h 4h 1d].freeze
    # Fast profile is used by frequent refreshes so each cycle stays short.
    FAST_PERIOD_BY_INTERVAL = {
      "15m" => "5d",
      "1h" => "10d",
      "4h" => "30d",
      "1d" => "120d"
    }.freeze
    # Full profile is used less frequently to refresh deeper history.
    FULL_PERIOD_BY_INTERVAL = {
      "15m" => "60d",
      "1h" => "30d",
      "4h" => "90d",
      "1d" => "2y"
    }.freeze

    def fetch_symbol(symbol, intervals: DEFAULT_INTERVALS)
      sym = symbol.to_s.upcase
      payload = fetch_symbols([ sym ], intervals:).first
      raise "yfinance fetch returned empty payload for #{sym}" if payload.blank?

      payload
    end

    # Batch mode avoids Python process spawn per symbol and reduces wall time.
    def fetch_symbols(symbols, intervals: DEFAULT_INTERVALS, period_by_interval: nil, timeout_seconds: 20)
      ivs = Array(intervals).map(&:to_s)
      syms = Array(symbols).map { |sym| sym.to_s.upcase }.uniq
      stdout, stderr, status = Open3.capture3(
        python_command,
        Rails.root.join("scripts/yfinance_fetch.py").to_s,
        "--symbols",
        syms.join(","),
        "--intervals",
        ivs.join(","),
        "--timeout-seconds",
        timeout_seconds.to_i.to_s,
        "--period-overrides",
        (period_by_interval || {}).to_json
      )

      unless status.success?
        raise "yfinance batch fetch failed for #{syms.join(',')}: #{stderr.presence || stdout}"
      end

      payload = JSON.parse(stdout)
      Array(payload["symbols"])
    rescue JSON::ParserError => e
      raise "yfinance fetch returned invalid JSON: #{e.message}"
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
