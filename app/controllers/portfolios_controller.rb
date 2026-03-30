class PortfoliosController < ApplicationController
  before_action :set_portfolio, only: [ :show ]

  def show
    @valuator = PortfolioValuationService.new
    @total_value = @valuator.total_value(@portfolio).to_f
    @starting = @portfolio.league.starting_capital.to_f
    @pnl = @total_value - @starting
    @rows = @portfolio.holdings.map do |h|
      last = @valuator.price_for_symbol(h.symbol).to_f
      avg = h.average_cost.to_f
      mkt = last * h.quantity
      cost = avg * h.quantity
      pnl = mkt - cost
      pnl_pct = cost.positive? ? (pnl / cost * 100.0) : 0.0
      { symbol: h.symbol, qty: h.quantity, avg: avg, last: last, mkt: mkt, pnl: pnl, pnl_pct: pnl_pct }
    end.sort_by { |r| -r[:mkt] }
  end

  private

  def set_portfolio
    @portfolio = Portfolio.find(params[:id])
  end
end
