class Admin::TeamMembershipsController < Admin::BaseController
  # Admin-only team membership removal (used for moderating team rosters).
  def destroy
    league = League.find(params[:league_id])
    team = league.teams.find(params[:team_id])
    membership = team.team_memberships.find(params[:id])

    membership.destroy
    redirect_back fallback_location: edit_admin_league_path(league), notice: "Removed user from team."
  rescue ActiveRecord::RecordNotFound
    redirect_back fallback_location: admin_leagues_path, alert: "Team membership not found."
  end
end
