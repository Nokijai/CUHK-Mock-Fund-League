module Api
  module V1
    class StocksController < BaseController
      # GET /api/v1/stocks/:symbol
      def show
        sym = params[:symbol].to_s.upcase
        payload = StockPriceService.new.get_price(sym)
        return render json: { error: "Stock not found" }, status: :not_found unless payload

        interval = params[:interval].to_s.presence
        if interval.present?
          limit = params[:limit].to_i
          limit = 200 if limit <= 0 || limit > 2000

          candles = StockCandle
            .for_symbol(sym)
            .for_interval(interval)
            .recent_first
            .limit(limit)
            .map do |c|
              {
                t: c.candle_at.iso8601,
                o: c.open&.to_f,
                h: c.high&.to_f,
                l: c.low&.to_f,
                c: c.close&.to_f,
                v: c.volume&.to_f
              }
            end

          payload = payload.merge(interval:, candles:)
        end

        render json: payload
      end
    end
  end
end
