module MarketData
  class RefreshSymbolService
    # Background-only refresh that persists latest price + candles to the DB.
    # The web request path should only read from the DB.
    def initialize(client: MarketData::YfinanceMarketDataService.new)
      @client = client
    end

    def call(symbol, intervals: MarketData::YfinanceMarketDataService::DEFAULT_INTERVALS)
      payload = @client.fetch_symbol(symbol, intervals:)
      call_payload(payload)
    end

    # Allows batch jobs to reuse the same persistence path after one shared fetch.
    def call_payload(payload)
      sym = payload.fetch("symbol").to_s.upcase

      ActiveRecord::Base.transaction do
        persist_price(sym, payload["price"])
        persist_candles(sym, payload.fetch("candles", {}))
      end

      true
    end

    private

    def persist_price(symbol, price)
      return if price.nil?

      sp = StockPrice.find_or_initialize_by(symbol:)
      sp.price = BigDecimal(price.to_s)
      sp.updated_at = Time.current
      sp.save!
    end

    def persist_candles(symbol, candles_hash)
      candles_hash.each do |interval, rows|
        next unless StockCandle::INTERVALS.include?(interval.to_s)
        Array(rows).each do |row|
          candle_at = Time.iso8601(row.fetch("t"))
          attrs = {
            symbol:,
            interval: interval.to_s,
            candle_at:,
            open: to_decimal(row["o"]),
            high: to_decimal(row["h"]),
            low: to_decimal(row["l"]),
            close: to_decimal(row["c"]),
            volume: to_decimal(row["v"])
          }

          # Upsert: new candle timestamps add rows; re-fetched same bar updates in place.
          # (No full-table replace; old bars not in the fetch window are left as-is.)
          StockCandle.upsert(
            attrs.merge(updated_at: Time.current, created_at: Time.current),
            unique_by: :index_stock_candles_on_symbol_interval_candle_at
          )
        end
      end
    end

    def to_decimal(val)
      return nil if val.nil?
      BigDecimal(val.to_s)
    end
  end
end
