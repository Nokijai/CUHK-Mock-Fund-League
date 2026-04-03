module Api
  module V1
    class LeagueMembershipsController < BaseController
      before_action :set_league

      # POST /api/v1/leagues/:league_id/memberships
      # Body: { user_id: 1 }
      def create
        user = User.find_by(id: membership_user_id)
        return render json: { errors: [ "User not found" ] }, status: :not_found unless user

        unless @league.join_open_now?
          # Keep API join rules aligned with web join flow and league schedule.
          error_message = @league.join_block_reason == :not_opened ? "League has not opened yet" : "League has expired"
          return render json: { errors: [ error_message ] }, status: :unprocessable_entity
        end

        if @league.full_for_new_members? && !@league.league_memberships.exists?(user_id: user.id)
          # Keep API behavior consistent with web join flow when league reaches capacity.
          return render json: { errors: [ "League is full" ] }, status: :unprocessable_entity
        end

        membership = LeagueMembership.new(user:, league: @league)
        begin
          saved = membership.save
        rescue ActiveRecord::RecordNotUnique
          return render json: { errors: [ "Already a member of this league" ] }, status: :unprocessable_entity
        end

        if saved
          # Keep portfolio provisioning coupled to membership creation.
          portfolio = Portfolio.find_or_create_by(user:, league: @league) do |p|
            p.cash_balance = @league.starting_capital
            p.total_value = @league.starting_capital
          end

          render json: {
            message: "Joined league",
            membership_id: membership.id,
            portfolio_id: portfolio.id,
            cash_balance: portfolio.cash_balance
          }, status: :created
        else
          render json: { errors: membership.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/leagues/:league_id/memberships/:user_id
      def destroy
        membership = @league.league_memberships.find_by(user_id: params[:user_id].to_i)
        return render json: { errors: [ "Membership not found" ] }, status: :not_found unless membership

        membership.destroy
        render json: { message: "Left league" }
      end

      private

      def set_league
        @league = League.find(params[:league_id])
      rescue ActiveRecord::RecordNotFound
        render json: { errors: [ "League not found" ] }, status: :not_found
      end

      # Accept body first, then path param so create and destroy stay consistent.
      def membership_user_id
        params[:user_id].presence || params[:id]
      end
    end
  end
end
