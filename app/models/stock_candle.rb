class StockCandle < ApplicationRecord
  # Candles are persisted snapshots fetched periodically (never fetched at request-time).
  # Order is tab order on the trading quote strip (shortest timeframe first).
  INTERVALS = %w[15m 1h 4h 1d].freeze

  validates :symbol, presence: true
  validates :interval, presence: true, inclusion: { in: INTERVALS }
  validates :candle_at, presence: true

  scope :for_symbol, ->(symbol) { where(symbol: symbol.to_s.upcase) }
  scope :for_interval, ->(interval) { where(interval:) }
  scope :recent_first, -> { order(candle_at: :desc) }
  # Oldest-first series for charting (paired with .last(n) on a recent window).
  scope :chronological, -> { order(candle_at: :asc) }
end
