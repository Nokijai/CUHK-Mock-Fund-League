class Users::OnboardingController < ApplicationController
  # Onboarding is part of the signed-in flow (we need current_user),
  # but it must be reachable before a league membership exists.

  def edit_username
    # Show the username picker form.
  end

  def update_username
    # Mark username as user-chosen so we don't keep redirecting after OAuth login.
    current_user.assign_attributes(username: params.dig(:user, :username).to_s)
    current_user.username_finalized = true

    if current_user.save
      redirect_to leagues_path, notice: "Username saved."
    else
      flash.now[:alert] = current_user.errors.full_messages.to_sentence
      render :edit_username, status: :unprocessable_entity
    end
  end
end
