class PortfoliosController < ApplicationController
  before_action :set_portfolio, only: [ :show ]

  def show
    # Keep portfolio views fresh: pending limits may become executable as prices move.
    Trade.process_pending_limits!

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

    # Build a complete ledger for this portfolio so users can audit all order outcomes.
    @transactions = @portfolio.trades.order(created_at: :desc)
    @trade_stats = build_trade_stats(@transactions)
  end

  private

  # Aggregates transaction metrics for portfolio dashboard cards.
  def build_trade_stats(trades)
    executed = trades.select(&:executed_at)
    pending = trades.reject(&:executed_at)

    executed_buy = executed.select { |trade| trade.trade_type == "buy" }
    executed_sell = executed.select { |trade| trade.trade_type == "sell" }

    {
      total_orders: trades.size,
      executed_orders: executed.size,
      pending_orders: pending.size,
      buy_orders: trades.count { |trade| trade.trade_type == "buy" },
      sell_orders: trades.count { |trade| trade.trade_type == "sell" },
      executed_quantity: executed.sum(&:quantity),
      executed_buy_notional: executed_buy.sum { |trade| trade.price.to_d * trade.quantity.to_i },
      executed_sell_notional: executed_sell.sum { |trade| trade.price.to_d * trade.quantity.to_i }
    }
  end

  def set_portfolio
    @portfolio = Portfolio.find(params[:id])
  end
end
