class PortfoliosController < ApplicationController
  before_action :set_portfolio, only: [ :show ]

  def show
  end

  private

  def set_portfolio
    @portfolio = Portfolio.find(params[:id])
  end
end
