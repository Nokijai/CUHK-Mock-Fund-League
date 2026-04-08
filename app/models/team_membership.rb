class TeamMembership < ApplicationRecord
  belongs_to :team, counter_cache: true
  belongs_to :user
  belongs_to :league

  before_validation :sync_league_from_team
  before_create :set_joined_at

  validates :user_id, uniqueness: { scope: :league_id, message: "is already in a team for this league" }
  validate :team_must_belong_to_league
  validate :team_must_not_be_full

  private

  def sync_league_from_team
    # Denormalize league_id for fast uniqueness checks (one team per user per league).
    self.league_id ||= team&.league_id
  end

  def set_joined_at
    self.joined_at ||= Time.current
  end

  def team_must_belong_to_league
    return if team.blank? || league.blank?

    errors.add(:team, "does not belong to this league") unless team.league_id == league_id
  end

  def team_must_not_be_full
    return if team.blank?

    errors.add(:team, "is full") if team.full?
  end
end
