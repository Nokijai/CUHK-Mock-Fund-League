class Team < ApplicationRecord
  belongs_to :league

  has_many :team_memberships, dependent: :destroy
  has_many :users, through: :team_memberships

  # Team join uses a shared secret; we store a digest, not plaintext.
  has_secure_password validations: true

  validates :name, presence: true, length: { maximum: 80 }
  validates :name, uniqueness: { scope: :league_id, case_sensitive: false }

  validate :league_must_be_team_mode
  validate :team_capacity_must_match_league_rules

  def full?
    max = league.team_max_participants
    return false if max.blank?

    team_memberships_count.to_i >= max.to_i
  end

  private

  def league_must_be_team_mode
    # Keep teams scoped to leagues explicitly configured for team play.
    errors.add(:league, "does not allow teams") unless league&.team_mode?
  end

  def team_capacity_must_match_league_rules
    # If the league has no explicit team max, we allow teams of any size.
    return unless league&.team_max_participants.present?

    if league.team_max_participants.to_i < 1
      errors.add(:base, "League team size must be a positive whole number")
    end
  end
end

