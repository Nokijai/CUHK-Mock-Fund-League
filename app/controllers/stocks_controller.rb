class StocksController < ApplicationController
  def search
    @results = StockPriceService.new.search(params[:q])
    render json: @results
  end

  def show
    @symbol = params[:symbol].upcase
    service = StockPriceService.new
    @quote = service.get_quote(@symbol)
    @history = service.get_history(@symbol, range: params[:range] || "1mo")

    respond_to do |format|
      format.html
      format.json { render json: { quote: @quote, history: @history } }
    end
  end
end
