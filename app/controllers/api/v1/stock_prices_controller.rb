module Api
  module V1
    class StockPricesController < ApplicationController
      def show
        price = StockPriceService.new.get_price(params[:symbol])
        if price
          render json: price
        else
          render json: { error: "Stock not found" }, status: :not_found
        end
      end
    end
  end
end
