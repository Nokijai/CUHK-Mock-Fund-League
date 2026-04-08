class TeamMembershipsController < ApplicationController
  def create
    league = League.find(params[:league_id])
    team = league.teams.find(params[:team_id])

    unless league.team_mode?
      redirect_to leagues_path(anchor: "league-#{league.id}"), alert: "This league does not use teams."
      return
    end

    unless league.join_open_now?
      alert_message = league.join_block_reason == :not_opened ? "This league has not opened yet." : "This league has expired."
      redirect_to leagues_path(anchor: "league-#{league.id}"), alert: alert_message
      return
    end

    if league.full_for_new_members? && !league.league_memberships.exists?(user_id: current_user.id)
      # Mirror web/API behavior: existing league members can still manage teams, but new users cannot join a full league.
      redirect_to leagues_path(anchor: "league-#{league.id}"), alert: "This league is already full."
      return
    end

    unless team.authenticate(join_params[:password].to_s)
      redirect_to leagues_path(anchor: "league-#{league.id}"), alert: "Incorrect team password."
      return
    end

    ActiveRecord::Base.transaction do
      TeamMembership.create!(team:, user: current_user, league:)
      # Ensure team members are also league members and have a portfolio.
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
          locals: { league:, team_membership:, inline_notice: "Joined team." }
        )
      end
      format.html do
        redirect_to leagues_path(anchor: "league-#{league.id}"), notice: "Joined team."
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.turbo_stream do
        league = League.includes(teams: { team_memberships: :user }).find(league.id)
        team_membership = TeamMembership.includes(team: :users).find_by(user_id: current_user.id, league_id: league.id)
        render turbo_stream: turbo_stream.replace(
          "league-teams-#{league.id}",
          partial: "leagues/team_mode_panel",
          locals: { league:, team_membership:, inline_alert: e.record.errors.full_messages.join(", ") }
        ), status: :unprocessable_entity
      end
      format.html do
        redirect_to leagues_path(anchor: "league-#{league.id}"), alert: e.record.errors.full_messages.join(", ")
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_back fallback_location: leagues_path, alert: "League/team not found."
  end

  private

  def join_params
    params.require(:team_join).permit(:password)
  end
end
