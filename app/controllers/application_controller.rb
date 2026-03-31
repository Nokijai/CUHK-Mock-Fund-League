class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :set_terminal_nav_context

  helper_method :show_admin_league_actions?

  private

  def set_terminal_nav_context
    @nav_league = League.order(:id).first
    demo = User.find_by(name: "Demo Trader")
    @nav_portfolio = demo&.portfolios&.first || Portfolio.order(:id).first
  end

  def show_admin_league_actions?
    uid = session[:user_id]
    return true if uid.blank?
    User.find_by(id: uid)&.role.to_s == "admin"
  end
end
