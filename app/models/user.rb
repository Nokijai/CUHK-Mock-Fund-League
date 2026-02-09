class User < ApplicationRecord
  has_many :league_memberships, dependent: :destroy
  has_many :leagues, through: :league_memberships
  has_many :portfolios, dependent: :destroy
end
