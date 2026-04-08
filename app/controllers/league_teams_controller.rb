class LeagueTeamsController < ApplicationController
  def create
    league = League.find(params[:league_id])

    unless league.team_mode?
      redirect_to leagues_path(anchor: "league-#{league.id}"), alert: "This league does not use teams."
      return
    end

    unless league.join_open_now?
      # Keep join window rules consistent for both team join and individual join.
      alert_message = league.join_block_reason == :not_opened ? "This league has not opened yet." : "This league has expired."
      redirect_to leagues_path(anchor: "league-#{league.id}"), alert: alert_message
      return
    end

    if league.full_for_new_members?
      redirect_to leagues_path(anchor: "league-#{league.id}"), alert: "This league is already full."
      return
    end

    if TeamMembership.exists?(user_id: current_user.id, league_id: league.id)
      respond_to do |format|
        format.turbo_stream do
          league = League.includes(teams: { team_memberships: :user }).find(league.id)
          team_membership = TeamMembership.includes(team: :users).find_by(user_id: current_user.id, league_id: league.id)
          render turbo_stream: turbo_stream.replace(
            "league-teams-#{league.id}",
            partial: "leagues/team_mode_panel",
            locals: { league:, team_membership:, inline_alert: "You can only create one team per league. Leave your current team first (admin can remove you if needed)." }
          ), status: :unprocessable_entity
        end
        format.html do
          redirect_to leagues_path(anchor: "league-#{league.id}"), alert: "You can only create one team per league."
        end
      end
      return
    end

    ActiveRecord::Base.transaction do
      team = league.teams.create!(team_params)

      TeamMembership.create!(team:, user: current_user, league:)
      # Keep league membership + portfolio provisioning coupled to the first team join.
      current_user.league_memberships.find_or_create_by!(league:)
      current_user.portfolios.find_or_create_by!(league:) do |portfolio|
        portfolio.cash_balance = league.starting_capital
      end
    end

    respond_to do |format|
      format.turbo_stream do
        # Re-render just the team panel to keep the league card open and avoid full-page rerender.
        league = League.includes(teams: { team_memberships: :user }).find(league.id)
        team_membership = TeamMembership.includes(team: :users).find_by(user_id: current_user.id, league_id: league.id)
        render turbo_stream: turbo_stream.replace(
          "league-teams-#{league.id}",
          partial: "leagues/team_mode_panel",
          locals: { league:, team_membership:, inline_notice: "Team created. You joined the team." }
        )
      end
      format.html do
        redirect_to leagues_path(anchor: "league-#{league.id}"), notice: "Team created. You joined the team."
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.turbo_stream do
        league = League.includes(teams: { team_memberships: :user }).find(params[:league_id])
        team_membership = TeamMembership.includes(team: :users).find_by(user_id: current_user.id, league_id: league.id)
        render turbo_stream: turbo_stream.replace(
          "league-teams-#{league.id}",
          partial: "leagues/team_mode_panel",
          locals: { league:, team_membership:, inline_alert: e.record.errors.full_messages.join(", ") }
        ), status: :unprocessable_entity
      end
      format.html do
        redirect_to leagues_path(anchor: "league-#{params[:league_id]}"), alert: e.record.errors.full_messages.join(", ")
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_back fallback_location: leagues_path, alert: "League not found."
  end

  def destroy
    league = League.find(params[:league_id])
    team = league.teams.find(params[:id])

    unless current_user.admin? || league.creator_id == current_user.id
      redirect_back fallback_location: leagues_path(anchor: "league-#{league.id}"), alert: "Only the league leader can delete teams."
      return
    end

    team.destroy

    respond_to do |format|
      format.turbo_stream do
        league = League.includes(teams: { team_memberships: :user }).find(league.id)
        team_membership = TeamMembership.includes(team: :users).find_by(user_id: current_user.id, league_id: league.id)
        render turbo_stream: turbo_stream.replace(
          "league-teams-#{league.id}",
          partial: "leagues/team_mode_panel",
          locals: { league:, team_membership:, inline_notice: "Team deleted." }
        )
      end
      format.html do
        redirect_to leagues_path(anchor: "league-#{league.id}"), notice: "Team deleted."
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_back fallback_location: leagues_path, alert: "League/team not found."
  end

  private

  def team_params
    # Password is required to join; we store its digest (has_secure_password).
    params.require(:team).permit(:name, :password, :password_confirmation)
  end
end

