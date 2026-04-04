class PortfoliosController < ApplicationController
  before_action :set_portfolio, only: [ :show ]

  def show
    # Only process limits for this portfolio — not the entire system.
    Trade.process_pending_limits!(portfolio: @portfolio)

    @valuator = PortfolioValuationService.new
    # Preload all holding symbols in one query instead of N find_by calls.
    @valuator.preload_symbols(@portfolio.holdings.map(&:symbol))
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
    # Reuse preloaded nav context from ApplicationController to avoid repeat queries.
    if @joined_leagues.blank?
      redirect_to leagues_path, alert: "Please join a league first."
      return
    end

    if params[:league_id].present?
      @portfolio = @league_portfolio_map[params[:league_id].to_i]
      unless @portfolio
        redirect_to leagues_path, alert: "Please select a league you joined."
        return
      end
    else
      @portfolio = @league_portfolio_map.values.find { |p| p.id == params[:id].to_i } ||
                   current_user.portfolios.find(params[:id])
    end

    @selected_league = @portfolio.league
    @nav_league = @selected_league
    @nav_portfolio = @portfolio
  end
end
