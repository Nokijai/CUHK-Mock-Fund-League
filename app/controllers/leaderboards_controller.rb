class LeaderboardsController < ApplicationController
  before_action :set_league

  def show
    @leagues = League.order(:name)
    @rankings = LeaderboardService.new(@league).compute
    @current_user_id = current_user_id
    @update_interval_minutes = @league.rules&.dig("leaderboard_update_minutes") || 15
    @last_updated_at = latest_snapshot_time
    @prizes = load_prizes
  end

  private

  def set_league
    @league = League.find(params[:league_id])
  end

  def current_user_id
    session[:user_id] || demo_user_id
  end

  def demo_user_id
    User.find_by(name: "Demo Trader")&.id || 0
  end

  def latest_snapshot_time
    PortfolioSnapshot
      .joins(:portfolio)
      .where(portfolios: { league_id: @league.id })
      .maximum(:updated_at) || Time.current
  end

  def load_prizes
    stored = @league.rules&.dig("prizes")
    return stored.map(&:symbolize_keys) if stored.present?

    [
      { rank: "1st Place", prize: "Champion Trophy" },
      { rank: "2nd Place", prize: "Silver Medal" },
      { rank: "3rd Place", prize: "Bronze Medal" }
    ]
  end
end
