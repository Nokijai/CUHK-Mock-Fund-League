module Api
  module V1
    class LeaguesController < BaseController
      before_action :set_league, only: [ :show, :update, :destroy ]

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
        # League leader is the authenticated API user creating the league.
        league.creator = current_user
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

      private

      def set_league
        @league = League.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        # Halt callback chain after responding to avoid double-render issues.
        render json: { errors: [ "League not found" ] }, status: :not_found and return
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
          members:          league.users.map { |u| { id: u.id, username: u.username, email: u.email } }
        }
      end

      def league_params
        # Rules + starting_capital fixed at creation; PATCH only allows descriptive/schedule fields.
        if action_name == "create"
          params.require(:league).permit(:name, :description, :starting_capital, :start_date, :end_date, rules: {})
        else
          params.require(:league).permit(:name, :description, :start_date, :end_date)
        end
      end
    end
  end
end
