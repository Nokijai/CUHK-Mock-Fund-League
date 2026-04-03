class Trade < ApplicationRecord
  belongs_to :portfolio

  # Supported side + order-type values mirror common broker semantics.
  SIDE_TYPES = %w[buy sell].freeze
  ORDER_TYPES = %w[market limit].freeze

  scope :pending_limits, -> { where(order_type: "limit", executed_at: nil) }

  before_validation :normalize_symbol
  before_validation :apply_market_price_default, on: :create
  before_create :execute_or_hold_on_create

  validates :symbol, presence: true
  validates :trade_type, inclusion: { in: SIDE_TYPES }
  validates :order_type, inclusion: { in: ORDER_TYPES }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :price, numericality: { greater_than: 0 }
  validate :validate_creation_constraints, on: :create

  # Attempts to execute pending limit orders against latest DB prices.
  # Accepts optional portfolio: and symbols: scopes to avoid scanning global pending orders.
  def self.process_pending_limits!(symbols: nil, portfolio: nil)
    relation = pending_limits.order(:created_at)
    relation = relation.where(portfolio_id: portfolio.id) if portfolio.present?
    relation = relation.where(symbol: Array(symbols).map(&:to_s).map(&:upcase)) if symbols.present?

    relation.find_each do |trade|
      trade.try_execute_pending_limit!
    end
  end

  def market_order?
    order_type == "market"
  end

  def limit_order?
    order_type == "limit"
  end

  def pending?
    executed_at.nil?
  end

  # Runs safe in-place execution for an already-persisted pending limit order.
  # Returns true only when order transitions to executed.
  def try_execute_pending_limit!
    return false unless persisted? && limit_order? && pending?

    latest = latest_price
    return false unless latest && limit_triggered_by?(latest)

    with_lock do
      return false unless pending? # double-check after lock

      portfolio.with_lock do
        # Re-check constraints at execution time (cash/holding may have changed).
        unless executable_with_price?(latest)
          return false
        end

        apply_execution!(latest)
        save!
      end
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  private

  def normalize_symbol
    self.symbol = symbol.to_s.strip.upcase
  end

  # Market order always uses latest known price as execution/default price.
  def apply_market_price_default
    return unless market_order?

    p = latest_price
    self.price = p if p
  end

  def validate_creation_constraints
    if market_order? && latest_price.blank?
      errors.add(:price, "is unavailable because latest market price was not found")
      return
    end

    # Validate placement-time constraints to match broker-like rejection behavior.
    unless executable_with_price?(price.to_d)
      # executable_with_price? sets detailed model errors.
      nil
    end
  end

  # For new records:
  # - market: execute immediately at latest price
  # - limit: execute now if trigger condition already met; otherwise hold pending
  def execute_or_hold_on_create
    market_px = latest_price
    execution_px = nil

    if market_order?
      execution_px = market_px
    elsif limit_order? && market_px && limit_triggered_by?(market_px)
      execution_px = market_px
    end

    return true if execution_px.blank? # keep pending limit order

    portfolio.with_lock do
      unless executable_with_price?(execution_px)
        throw(:abort)
      end

      apply_execution!(execution_px)
    end
  end

  def apply_execution!(execution_price)
    p = execution_price.to_d
    qty = quantity.to_i
    holding = portfolio.holdings.lock.find_or_initialize_by(symbol: symbol)
    holding.quantity ||= 0
    holding.average_cost ||= 0

    if trade_type == "buy"
      total_cost = p * qty
      portfolio.cash_balance = portfolio.cash_balance.to_d - total_cost

      old_qty = holding.quantity.to_i
      old_avg = holding.average_cost.to_d
      new_qty = old_qty + qty
      weighted_cost = (old_avg * old_qty) + total_cost

      holding.quantity = new_qty
      holding.average_cost = new_qty.positive? ? (weighted_cost / new_qty) : 0
      holding.save!
    else
      holding_qty = holding.quantity.to_i
      raise ActiveRecord::RecordInvalid, self if holding_qty < qty

      proceeds = p * qty
      portfolio.cash_balance = portfolio.cash_balance.to_d + proceeds

      remaining = holding_qty - qty
      if remaining.zero?
        holding.destroy! if holding.persisted?
      else
        holding.quantity = remaining
        # Keep average cost unchanged after partial sell.
        holding.save!
      end
    end

    portfolio.save!
    self.price = p
    self.executed_at = Time.current
  end

  def executable_with_price?(execution_price)
    px = execution_price.to_d
    qty = quantity.to_i

    if trade_type == "buy"
      total_cost = px * qty
      if portfolio.cash_balance.to_d < total_cost
        errors.add(:base, "Insufficient cash balance for this order")
        return false
      end
    else
      holding_qty = portfolio.holdings.find_by(symbol: symbol)&.quantity.to_i
      if holding_qty < qty
        errors.add(:base, "Insufficient holding quantity to sell")
        return false
      end
    end

    true
  end

  def limit_triggered_by?(market_price)
    p = market_price.to_d
    lim = price.to_d
    return p <= lim if trade_type == "buy"

    p >= lim
  end

  def latest_price
    StockPrice.find_by(symbol: symbol)&.price&.to_d
  end
end
