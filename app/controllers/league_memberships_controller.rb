class LeagueMembershipsController < ApplicationController
  before_action :set_league_membership, only: [ :destroy ]

  def index
    @league_memberships = LeagueMembership.all
  end

  def create
    league = League.find(league_membership_params[:league_id])
    @league_membership = current_user.league_memberships.find_or_initialize_by(league: league)

    if @league_membership.persisted?
      redirect_to leagues_path(anchor: "league-#{league.id}"), notice: "You are already registered for this league."
      return
    end

    unless league.join_open_now?
      # Enforce registration window before allowing new members.
      alert_message = league.join_block_reason == :not_opened ? "This league has not opened yet." : "This league has expired."
      redirect_to leagues_path(anchor: "league-#{league.id}"), alert: alert_message
      return
    end

    if league.full_for_new_members?
      # Capacity rule comes from admin-configured league.rules max_participants.
      redirect_to leagues_path(anchor: "league-#{league.id}"), alert: "This league is already full."
      return
    end

    ActiveRecord::Base.transaction do
      @league_membership.save!
      # Ensure joined users can immediately trade by having a portfolio in this league.
      current_user.portfolios.find_or_create_by!(league: league) do |portfolio|
        portfolio.cash_balance = league.starting_capital
      end
    end

    redirect_to leagues_path(anchor: "league-#{league.id}"), notice: "Successfully registered for the league."
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: leagues_path, alert: e.record.errors.full_messages.join(", ")
  rescue ActiveRecord::RecordNotFound
    redirect_back fallback_location: leagues_path, alert: "League not found."
  end

  def destroy
    if @league_membership.user_id != current_user.id
      redirect_back fallback_location: leagues_path, alert: "You can only leave your own memberships."
      return
    end

    unless @league_membership.league.quit_open_now?
      redirect_to leagues_path(anchor: "league-#{@league_membership.league_id}"), alert: "You can only leave a league before it starts."
      return
    end

    # leave_with_cleanup! clears team + portfolio rows so the user is fully detached from the league.
    league_id = @league_membership.league_id
    @league_membership.leave_with_cleanup!
    redirect_to leagues_path(anchor: "league-#{league_id}"), notice: "Successfully unregistered from the league."
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey => e
    redirect_back fallback_location: leagues_path, alert: "Could not leave the league: #{e.message}"
  end

  private

  def set_league_membership
    @league_membership = LeagueMembership.find(params[:id])
  end

  def league_membership_params
    # Force user ownership from session; never trust client-supplied user_id.
    params.require(:league_membership).permit(:league_id)
  end
end
