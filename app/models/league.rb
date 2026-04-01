class League < ApplicationRecord
  include Searchable
  
  has_many :league_memberships, dependent: :destroy
  has_many :users, through: :league_memberships
  has_many :portfolios, dependent: :destroy

  # Keep league names unique and enforce valid competition windows/capital.
  validates :name, presence: true, uniqueness: { case_sensitive: true, message: "already exists" }
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :starting_capital, presence: true, numericality: { greater_than: 0 }
  validate :start_date_must_be_in_future, on: :create
  validate :end_date_after_start_date

  private

  def start_date_must_be_in_future
    if start_date.present? && start_date < Time.current
      errors.add(:start_date, "must be in the future")
    end
  end

  def end_date_after_start_date
    if start_date.present? && end_date.present? && end_date <= start_date
      errors.add(:end_date, "must be after start date")
    end
  end
end
