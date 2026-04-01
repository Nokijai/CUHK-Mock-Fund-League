class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :set_terminal_nav_context
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :show_admin_league_actions?

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name])
  end

  def set_terminal_nav_context
    # Load joined leagues from membership rows so selection is always membership-backed.
    joined_memberships = current_user ? current_user.league_memberships.includes(:league).order(:joined_at) : []
    @joined_leagues = joined_memberships.map(&:league).compact
    @league_portfolio_map = current_user ? current_user.portfolios.index_by(&:league_id) : {}

    requested_league_id = params[:league_id].presence
    selected_membership = if requested_league_id.present? && current_user
      # Validate league_id against DB membership for current user.
      current_user.league_memberships.includes(:league).find_by(league_id: requested_league_id)
    end
    @selected_league = selected_membership&.league || @joined_leagues.first

    # Keep top-nav links consistent with the user's selected league context.
    @nav_league = @selected_league
    @nav_portfolio = @league_portfolio_map[@selected_league&.id] || current_user&.portfolios&.first
  end

  def show_admin_league_actions?
    return false unless current_user
    current_user.role.to_s == "admin"
  end
end
