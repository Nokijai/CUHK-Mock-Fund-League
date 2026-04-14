class LeaderboardsController < ApplicationController
  before_action :set_league_archive, only: [ :index ]
  before_action :set_league, only: [ :show ]

  def index
  end

  def show
    if @league.team_mode?
      @rankings = TeamLeaderboardService.new(@league).compute
      @current_entry_id = TeamMembership.find_by(user_id: current_user.id, league_id: @league.id)&.team_id.to_i
      @entry_kind = :team
    else
      @rankings = LeaderboardService.new(@league).compute
      @current_entry_id = current_user&.id || 0
      @entry_kind = :user
    end
    @update_interval_minutes = @league.rules&.dig("leaderboard_update_minutes") || 15
    @last_updated_at = latest_snapshot_time
    @prizes = load_prizes
  end

  private

  def set_league
    @league = League.find(params[:league_id])
  end

  def set_league_archive
    all_leagues = League
      .includes(:creator)
      .where("start_date <= ?", Date.current)
      .order(start_date: :desc, name: :asc)
    @leagues_by_month = all_leagues.group_by { |league| league.start_date&.to_date&.beginning_of_month }
    @leagues_by_month = @leagues_by_month.reject { |month, _| month.blank? }
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
