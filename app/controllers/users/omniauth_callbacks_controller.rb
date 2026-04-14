class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # OAuth callbacks are invoked by OmniAuth after the provider redirects back.
  # We keep logic in the User model (`User.from_omniauth`) so we can reuse it in tests/jobs.

  def google_oauth2
    handle_oauth("Google")
  end

  def github
    handle_oauth("GitHub")
  end

  def failure
    # Keep messaging generic to avoid leaking provider internals.
    redirect_to new_user_session_path, alert: "Social login failed. Please try again or use email/password."
  end

  private

  def handle_oauth(provider_label)
    auth = request.env["omniauth.auth"]
    user = User.from_omniauth(auth)

    sign_in user, event: :authentication

    # New OAuth users should explicitly choose a username before entering the app.
    if user.respond_to?(:username_finalized) && !user.username_finalized
      return redirect_to edit_users_onboarding_username_path
    end

    redirect_to root_path
    set_flash_message(:notice, :success, kind: provider_label) if is_navigational_format?
  rescue => e
    Rails.logger.warn("[oauth] #{provider_label} callback failed: #{e.class}: #{e.message}")
    redirect_to new_user_session_path, alert: "Could not sign in with #{provider_label}. Please try again."
  end
end
