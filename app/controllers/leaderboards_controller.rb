class LeaderboardsController < ApplicationController
  before_action :set_league, only: [ :show ]

  def show
    @rankings = LeaderboardService.new(@league).compute
  end

  private

  def set_league
    @league = League.find(params[:league_id])
  end
end
