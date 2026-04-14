# Awards experience points to all participants when a league ends.
# XP = percentage change of portfolio (with handling fee bonus) + placement bonus for top 3.
class ExperienceAwardService
  PLACEMENT_BONUS = { 1 => 30, 2 => 20, 3 => 10 }.freeze

  def initialize(league)
    @league = league
    @handling_fee = league.handling_fee_proportion.to_f
  end

  def award!
    rankings = compute_rankings
    return if rankings.empty?

    rankings.each do |entry|
      user = find_user(entry)
      next unless user

      xp = compute_xp(entry)
      bonus = PLACEMENT_BONUS[entry[:rank]] || 0
      total = xp + bonus

      user.award_experience!(total) unless total.zero?
    end
  end

  private

  def compute_rankings
    if @league.team_mode?
      team_rankings = TeamLeaderboardService.new(@league).compute
      expand_team_rankings(team_rankings)
    else
      LeaderboardService.new(@league).compute
    end
  end

  def expand_team_rankings(team_rankings)
    team_rankings.flat_map do |team_entry|
      team = Team.find_by(id: team_entry[:team_id])
      next [] unless team

      team.users.map do |user|
        {
          user_id: user.id,
          rank: team_entry[:rank],
          total_return_pct: team_entry[:avg_return_pct] || 0.0
        }
      end
    end
  end

  def find_user(entry)
    User.find_by(id: entry[:user_id])
  end

  def compute_xp(entry)
    base_xp = (entry[:total_return_pct] || 0).round.to_i

    if base_xp.positive? && @handling_fee.positive?
      # Bonus multiplier: earned XP * (1 + handling_fee * 10)
      (base_xp * (1 + @handling_fee * 10)).round.to_i
    else
      base_xp
    end
  end
end
