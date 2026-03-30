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
    @nav_league = League.order(:id).first
    @nav_portfolio = current_user&.portfolios&.first || Portfolio.order(:id).first
  end

  def show_admin_league_actions?
    return false unless current_user
    current_user.role.to_s == "admin"
  end
end
