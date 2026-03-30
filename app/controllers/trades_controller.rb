class TradesController < ApplicationController
  before_action :set_trade, only: [ :show ]
  before_action :set_portfolio, only: [ :index, :new, :create ]

  def index
    @trades = @portfolio.trades
  end

  def show
  end

  def new
    sym = params[:prefill_symbol].to_s.upcase.presence
    pr = params[:prefill_price]
    price = pr.present? ? BigDecimal(pr.to_s) : nil
    @trade = Trade.new(portfolio: @portfolio, symbol: sym, price: price)
    @available_stocks = StockPrice.order(:symbol)
  end

  def create
    @trade = Trade.new(trade_params.merge(portfolio: @portfolio))
    if @trade.save
      redirect_to @portfolio, notice: "Trade was successfully executed."
    else
      @available_stocks = StockPrice.order(:symbol)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_trade
    @trade = Trade.find(params[:id])
  end

  def set_portfolio
    @portfolio = Portfolio.find(params[:portfolio_id])
  end

  def trade_params
    params.require(:trade).permit(:symbol, :trade_type, :quantity, :price)
  end
end
