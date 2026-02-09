module Api
  module V1
    class TradesController < ApplicationController
      def create
        result = TradeExecutionService.new.execute(trade_params)
        if result.success?
          render json: result.trade, status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      private

      def trade_params
        params.require(:trade).permit(:portfolio_id, :symbol, :trade_type, :quantity, :price)
      end
    end
  end
end
