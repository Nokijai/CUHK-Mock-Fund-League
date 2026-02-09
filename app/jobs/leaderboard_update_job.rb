class LeaderboardUpdateJob < ApplicationJob
  queue_as :default

  def perform(league_id)
    league = League.find_by(id: league_id)
    return unless league
    LeaderboardService.new(league).compute
  end
end
