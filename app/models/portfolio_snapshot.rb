class PortfolioSnapshot < ApplicationRecord
  belongs_to :portfolio

  validates :snapshot_date, presence: true
  validates :total_value, presence: true
  validates :portfolio_id, uniqueness: { scope: :snapshot_date }

  scope :ordered, -> { order(:snapshot_date) }
  scope :recent, ->(n) { order(snapshot_date: :desc).limit(n) }
end
