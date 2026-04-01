class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :redirect_pending_otp_user
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

  def redirect_pending_otp_user
    return if user_signed_in?
    return unless session[:pending_otp_user_id].present?
    return if devise_controller? && %w[sessions].include?(controller_name) && %w[verify_otp otp_authenticate cancel_otp_login resend_otp].include?(action_name)

    redirect_to users_verify_otp_path, alert: "Please complete email verification before continuing."
  end

  def show_admin_league_actions?
    return false unless current_user
    current_user.role.to_s == "admin"
  end
end
