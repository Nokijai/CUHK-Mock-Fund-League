class LeagueMembership < ApplicationRecord
  belongs_to :user
  belongs_to :league

  before_create :set_joined_at

  private

  def set_joined_at
    self.joined_at ||= Time.current
  end
end
