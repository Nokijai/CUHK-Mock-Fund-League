class Portfolio < ApplicationRecord
  belongs_to :user
  belongs_to :league
  has_many :holdings, dependent: :destroy
  has_many :trades, dependent: :destroy
end
