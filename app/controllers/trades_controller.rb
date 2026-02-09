class TradesController < ApplicationController
  before_action :set_trade, only: [:show]
  before_action :set_portfolio, only: [:new, :create]

  def index
    @trades = Trade.all
  end

  def show
  end

  def new
    @trade = Trade.new(portfolio: @portfolio)
  end

  def create
    @trade = Trade.new(trade_params.merge(portfolio: @portfolio))
    if @trade.save
      redirect_to @portfolio, notice: "Trade was successfully executed."
    else
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
