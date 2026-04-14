class ApplicationController < ActionController::Base
  # Browser gating is helpful in production, but it can interfere with request specs (which
  # often use Rack::Test and synthetic user agents). Keep CI/test stable by disabling it.
  allow_browser versions: :modern unless Rails.env.test?
  stale_when_importmap_changes

  before_action :redirect_pending_otp_user
  before_action :authenticate_user!
  before_action :set_terminal_nav_context
  # Gate the rest of the app until the user has joined at least one league (browse/join stays on /leagues).
  before_action :require_joined_league
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :show_admin_league_actions?

  protected

  def after_sign_out_path_for(_resource_or_scope)
    new_user_session_path
  end

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
    running_memberships = joined_memberships.select { |membership| membership.league&.running_now? }
    @running_leagues = running_memberships.map(&:league).compact
    # Load once and reuse instead of querying current_user.portfolios multiple times.
    user_portfolios = current_user.portfolios.to_a
    running_league_ids = @running_leagues.map(&:id)
    @league_portfolio_map = user_portfolios.select { |portfolio| running_league_ids.include?(portfolio.league_id) }.index_by(&:league_id)

    requested_league_id = params[:league_id].presence
    selected_membership = if requested_league_id.present?
      # Reuse preloaded memberships to avoid an extra query per request.
      running_memberships.find { |membership| membership.league_id == requested_league_id.to_i }
    end
    @selected_league = selected_membership&.league || @running_leagues.first

    # Keep top-nav links consistent with the user's selected league context.
    @nav_league = @selected_league
    @nav_portfolio = @league_portfolio_map[@selected_league&.id] || @league_portfolio_map.values.first
  end

  def set_guest_nav_context
    @joined_leagues = []
    @running_leagues = []
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

    pending_signup_user_id = session[:pending_signup_user_id]
    return if pending_signup_user_id.blank?

    pending_user = User.find_by(id: pending_signup_user_id)
    unless pending_user&.signup_pending?
      # Admin may approve the user while they are on the OTP page.
      # Keep the session flag so RegistrationsController#verify_otp can sign them in.
      return
    end
    return if devise_controller? && (
      (controller_name == "registrations" && %w[new create verify_otp otp_authenticate cancel_otp_signup resend_otp].include?(action_name))
    )

    redirect_to users_verify_signup_otp_path, alert: "Please complete email verification before continuing."
  end

  def show_admin_league_actions?
    return false unless current_user
    current_user.role.to_s == "admin"
  end

  # Send users with no league membership to the leagues list so they can join (or join a team) first.
  def require_joined_league
    return if allow_request_without_joined_league?

    redirect_to leagues_path, alert: "Please join a league to continue."
  end

  def allow_request_without_joined_league?
    return true unless user_signed_in?
    # Single EXISTS query — avoids relying on nav preloads here.
    return true if current_user.league_memberships.exists?

    return true if controller_path.start_with?("admin/")
    return true if controller_path.start_with?("api/")
    return true if devise_controller?

    case controller_path
    when "leagues"
      # List/detail routes for picking a league; join actions hit other controllers below.
      %w[index show].include?(action_name)
    when "league_memberships"
      true
    when "league_teams", "team_memberships"
      # Team-mode join/create flows must work before a membership row exists.
      true
    when "users/onboarding"
      # OAuth users must be able to set username before joining a league.
      true
    when "friendships", "friend_requests"
      true
    when "messages"
      true
    when "profiles"
      true
    else
      false
    end
  end

  def apply_fuzzy_search(scope, fields, raw_query)
    patterns = fuzzy_patterns(raw_query)
    normalized_fields = Array(fields).map(&:to_s).reject(&:blank?)
    return scope if patterns.empty? || normalized_fields.empty?

    conditions = normalized_fields.flat_map do |field|
      Array.new(patterns.length, "#{field} ILIKE ?")
    end.join(" OR ")
    values = normalized_fields.flat_map { patterns }

    scope.where(conditions, *values)
  end

  def fuzzy_patterns(raw_query)
    query = raw_query.to_s.strip
    return [] if query.blank?

    safe_query = ActiveRecord::Base.sanitize_sql_like(query)
    squashed = safe_query.gsub(/\s+/, " ")
    compact_chars = squashed.delete(" ")
    tokens = squashed.split(" ")

    patterns = []
    patterns << "%#{squashed}%"
    patterns << "%#{compact_chars.chars.join('%')}%" if compact_chars.present?
    patterns << "%#{tokens.join('%')}%" if tokens.any?
    patterns.uniq
  end
end
