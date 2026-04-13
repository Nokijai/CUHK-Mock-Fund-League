module Api
  module V1
    class TradesController < BaseController
      # POST /api/v1/portfolios/:portfolio_id/trades
      def create
        # Path param is the source of truth for resource association.
        result = TradeExecutionService.new.execute(trade_params.merge(portfolio_id: params[:portfolio_id]))
        if result.success?
          render json: result.trade, status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      private

      def trade_params
        params.require(:trade).permit(:symbol, :trade_type, :order_type, :quantity, :price)
      end
    end
  end
end
