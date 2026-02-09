class StocksController < ApplicationController
  def search
    @results = StockPriceService.new.search(params[:q])
    render json: @results
  end

  def show
    @stock = StockPriceService.new.get_price(params[:symbol])
    render json: @stock
  end
end
