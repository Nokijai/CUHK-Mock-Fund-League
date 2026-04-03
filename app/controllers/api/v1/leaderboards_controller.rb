module Api
  module V1
    class LeaderboardsController < BaseController
      before_action :set_league

      # GET /api/v1/leagues/:league_id/leaderboard
      def show
        standings = LeaderboardService.new(@league).compute

        render json: {
          league_id: @league.id,
          league_name: @league.name,
          # Rank is derived at render-time to avoid persisting transient order.
          standings: standings.each_with_index.map { |entry, idx| entry.merge(rank: idx + 1) }
        }
      end

      private

      def set_league
        @league = League.find(params[:league_id])
      rescue ActiveRecord::RecordNotFound
        render json: { errors: [ "League not found" ] }, status: :not_found
      end
    end
  end
end
