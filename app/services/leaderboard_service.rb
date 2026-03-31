class LeaderboardService
  def initialize(league)
    @league = league
  end

  def compute
    valuator = PortfolioValuationService.new
    @league.portfolios.includes(:user, :holdings).map do |p|
      {
        user_id: p.user_id,
        name: p.user&.name.presence || p.user&.email || "User ##{p.user_id}",
        value: valuator.total_value(p).to_f
      }
    end.sort_by { |r| -r[:value] }
  end
end
