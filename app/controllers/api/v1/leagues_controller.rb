module Api
  module V1
    class LeaguesController < BaseController
      before_action :set_league, only: [ :show, :update, :destroy, :join, :leave, :leaderboard ]

      # GET /api/v1/leagues
      def index
        leagues = League.all.includes(:league_memberships)
        render json: leagues.map { |league| league_summary(league) }
      end

      # GET /api/v1/leagues/:id
      def show
        render json: league_detail(@league)
      end

      # POST /api/v1/leagues
      def create
        league = League.new(league_params)
        if league.save
          render json: league_detail(league), status: :created
        else
          render json: { errors: league.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/leagues/:id
      def update
        if @league.update(league_params)
          render json: league_detail(@league)
        else
          render json: { errors: @league.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/leagues/:id
      def destroy
        @league.destroy
        render json: { message: "League deleted" }
      end

      # POST /api/v1/leagues/:id/join
      # Body: { user_id: 1 }
      def join
        user_id = params[:user_id].to_i
        user = User.find_by(id: user_id)
        return render json: { errors: [ "User not found" ] }, status: :not_found unless user

        membership = LeagueMembership.new(user: user, league: @league)
        begin
          saved = membership.save
        rescue ActiveRecord::RecordNotUnique
          return render json: { errors: [ "Already a member of this league" ] }, status: :unprocessable_entity
        end

        if saved
          # Provision a portfolio for this user in the league if one doesn't exist yet
          portfolio = Portfolio.find_or_create_by(user: user, league: @league) do |p|
            p.cash_balance = @league.starting_capital
            p.total_value  = @league.starting_capital
          end
          render json: {
            message:      "Joined league",
            membership_id: membership.id,
            portfolio_id:  portfolio.id,
            cash_balance:  portfolio.cash_balance
          }, status: :created
        else
          render json: { errors: membership.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/leagues/:id/leave
      # Body: { user_id: 1 }
      def leave
        user_id = params[:user_id].to_i
        membership = @league.league_memberships.find_by(user_id: user_id)
        return render json: { errors: [ "Membership not found" ] }, status: :not_found unless membership

        membership.destroy
        render json: { message: "Left league" }
      end

      # GET /api/v1/leagues/:id/leaderboard
      def leaderboard
        standings = LeaderboardService.new(@league).compute
        render json: {
          league_id: @league.id,
          league_name: @league.name,
          standings: standings.each_with_index.map { |entry, idx|
            entry.merge(rank: idx + 1)
          }
        }
      end

      private

      def set_league
        @league = League.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { errors: [ "League not found" ] }, status: :not_found
      end

      def league_summary(league)
        {
          id:               league.id,
          name:             league.name,
          description:      league.description,
          starting_capital: league.starting_capital,
          start_date:       league.start_date,
          end_date:         league.end_date,
          member_count:     league.league_memberships.size
        }
      end

      def league_detail(league)
        {
          id:               league.id,
          name:             league.name,
          description:      league.description,
          starting_capital: league.starting_capital,
          start_date:       league.start_date,
          end_date:         league.end_date,
          rules:            league.rules,
          member_count:     league.league_memberships.count,
          members:          league.users.map { |u| { id: u.id, name: u.name, email: u.email } }
        }
      end

      def league_params
        params.require(:league).permit(:name, :description, :starting_capital, :start_date, :end_date, rules: {})
      end
    end
  end
end

