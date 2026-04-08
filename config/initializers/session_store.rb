Rails.application.config.session_store(
  :cookie_store,
  key: "_cuhk_mock_fund_league_session",
  # Baseline protections for session cookies.
  same_site: :lax,
  secure: Rails.env.production?,
  httponly: true
)
