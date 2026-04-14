class LeagueMembership < ApplicationRecord
  belongs_to :user
  belongs_to :league

  before_create :set_joined_at

  # Full exit: team seat (team-mode), portfolio + holdings/trades, then this membership row.
  def leave_with_cleanup!
    ActiveRecord::Base.transaction do
      user.team_memberships.where(league_id: league_id).destroy_all
      user.portfolios.where(league_id: league_id).destroy_all
      destroy!
    end
  end

  private

  def set_joined_at
    self.joined_at ||= Time.current
  end
end
