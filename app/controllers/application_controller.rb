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
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :username ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :username ])
  end

  def set_terminal_nav_context
    # Load joined leagues from membership rows so selection is always membership-backed.
    return set_guest_nav_context unless current_user

    joined_memberships = current_user.league_memberships.includes(:league).order(:joined_at).to_a
    @joined_leagues = joined_memberships.map(&:league).compact
    # Load once and reuse instead of querying current_user.portfolios multiple times.
    user_portfolios = current_user.portfolios.to_a
    @league_portfolio_map = user_portfolios.index_by(&:league_id)

    requested_league_id = params[:league_id].presence
    selected_membership = if requested_league_id.present?
      # Reuse preloaded memberships to avoid an extra query per request.
      joined_memberships.find { |membership| membership.league_id == requested_league_id.to_i }
    end
    @selected_league = selected_membership&.league || @joined_leagues.first

    # Keep top-nav links consistent with the user's selected league context.
    @nav_league = @selected_league
    @nav_portfolio = @league_portfolio_map[@selected_league&.id] || user_portfolios.first
  end

  def set_guest_nav_context
    @joined_leagues = []
    @league_portfolio_map = {}
    @selected_league = nil
    @nav_league = nil
    @nav_portfolio = nil
  end

  # Keep pending signup or login OTP users inside the verification flow until completion.
  def redirect_pending_otp_user
    return if user_signed_in?

    if session[:pending_otp_user_id].present?
      return if devise_controller? && (
        controller_name == "sessions" && %w[new create verify_otp otp_authenticate cancel_otp_login resend_otp].include?(action_name)
      )

      redirect_to users_verify_otp_path, alert: "Please complete login verification before continuing."
      return
    end

    return unless session[:pending_signup].present?
    return if devise_controller? && (
      (controller_name == "registrations" && %w[new create verify_otp otp_authenticate cancel_otp_signup resend_otp].include?(action_name))
    )

    redirect_to users_verify_signup_otp_path, alert: "Please complete email verification before continuing."
  end

  def redirect_pending_otp_user
    return if user_signed_in?
    return unless session[:pending_otp_user_id].present?
    return if devise_controller? && (
      (controller_name == "sessions" && %w[new create verify_otp otp_authenticate cancel_otp_login resend_otp].include?(action_name)) ||
      (controller_name == "registrations" && %w[new create].include?(action_name))
    )

    redirect_to users_verify_otp_path, alert: "Please complete email verification before continuing."
  end

  def show_admin_league_actions?
    return false unless current_user
    current_user.role.to_s == "admin"
  end
end
