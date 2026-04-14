module LeaderboardsHelper
  # Returns :active (green), :ended (red), or :upcoming (yellow)
  def league_status(league)
    today = Date.current
    if league.start_date.present? && league.end_date.present?
      if today < league.start_date
        :upcoming
      elsif today > league.end_date
        :ended
      else
        :active
      end
    else
      :upcoming
    end
  end

  # Human-readable prize summary for filter data attributes
  def league_prizes_text(league)
    stored = league.rules&.dig("prizes")
    if stored.present?
      stored.map { |p| p["prize"] || p[:prize] }.compact.join(", ")
    else
      "Champion Trophy, Silver Medal, Bronze Medal"
    end
  end

  # Human-readable rules summary for filter data attributes
  def league_rules_text(league)
    parts = []
    parts << "Team mode" if league.team_mode?
    parts << "Max #{league.max_participants}" if league.max_participants.present?
    parts << "Fee #{(league.handling_fee_proportion * 100).round(1)}%" if league.handling_fee_rule_configured?
    parts << "Min balance #{league.minimum_final_balance}" if league.minimum_final_balance.present?
    parts << "Capital $#{league.starting_capital.to_i}" if league.starting_capital.present?
    parts.join(", ")
  end
end
