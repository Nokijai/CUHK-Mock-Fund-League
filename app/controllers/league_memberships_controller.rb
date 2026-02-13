class LeagueMembershipsController < ApplicationController
  before_action :set_league_membership, only: [ :show, :destroy ]

  def index
    @league_memberships = LeagueMembership.all
  end

  def show
  end

  def create
    @league_membership = LeagueMembership.new(league_membership_params)
    if @league_membership.save
      redirect_to @league_membership.league, notice: "Successfully joined the league."
    else
      redirect_back fallback_location: leagues_path, alert: @league_membership.errors.full_messages.join(", ")
    end
  end

  def destroy
    @league_membership.destroy
    redirect_to leagues_path, notice: "Successfully left the league."
  end

  private

  def set_league_membership
    @league_membership = LeagueMembership.find(params[:id])
  end

  def league_membership_params
    params.require(:league_membership).permit(:user_id, :league_id)
  end
end
