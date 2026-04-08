class Users::SessionsController < Devise::SessionsController
  skip_before_action :authenticate_user!, only: %i[new create verify_otp otp_authenticate cancel_otp_login resend_otp]
  before_action :ensure_pending_otp_user!, only: %i[verify_otp otp_authenticate resend_otp]

  def create
    # Accept username or email in the Devise "email" field (see User.find_for_database_authentication).
    login = sign_in_params[:email].to_s.strip
    password = sign_in_params[:password].to_s

    user = User.find_for_database_authentication(email: login)

    unless user&.valid_password?(password)
      self.resource = resource_class.new(sign_in_params)
      flash.now[:alert] = "Invalid username/email or password."
      clean_up_passwords(resource)
      render :new, status: :unprocessable_entity
      return
    end

    if user.signup_pending?
      # Keep unverified signups inside the signup verification flow.
      session[:pending_signup_user_id] = user.id
      redirect_to users_verify_signup_otp_path, alert: "Please verify your email before logging in."
      return
    end

    if user.skip_login_otp
      # Admin-approved users can sign in without login OTP.
      sign_out(resource_name) if user_signed_in?
      session.delete(:pending_otp_user_id)
      session.delete(:pending_otp_remember_me)

      # Prevent session fixation on step-up/bypass authentication.
      reset_session
      sign_in(resource_name, user)
      remember_requested = ActiveModel::Type::Boolean.new.cast(sign_in_params[:remember_me])
      remember_me(user) if remember_requested && devise_mapping.rememberable?

      redirect_to after_sign_in_path_for(user), notice: "Logged in successfully."
      return
    end

    # Seeded admin uses a non-deliverable address (db/seeds.rb); skip OTP only in development
    # so local sign-in works without SMTP. Production still requires email verification for admins.
    if Rails.env.development? && user.admin?
      sign_out(resource_name) if user_signed_in?
      session.delete(:pending_otp_user_id)
      session.delete(:pending_otp_remember_me)

      # Prevent session fixation in local admin fast-path.
      reset_session
      sign_in(resource_name, user)
      remember_requested = ActiveModel::Type::Boolean.new.cast(sign_in_params[:remember_me])
      remember_me(user) if remember_requested && devise_mapping.rememberable?

      redirect_to after_sign_in_path_for(user), notice: "Logged in successfully."
      return
    end

    code = user.generate_login_otp!
    # OTP emails are queued to avoid blocking the request (and reduce abuse amplification).
    UserMailer.login_otp_email(user, code).deliver_later

    sign_out(resource_name) if user_signed_in?

    session[:pending_otp_user_id] = user.id
    session[:pending_otp_remember_me] = sign_in_params[:remember_me]

    redirect_to users_verify_otp_path, notice: "A verification code was sent to your email."
  end

  def verify_otp
  end

  def otp_authenticate
    code = params[:otp_code].to_s.strip

    if @pending_user.login_otp_locked?
      redirect_to users_verify_otp_path, alert: "Too many failed attempts. Please wait and try again."
      return
    end

    if @pending_user.verify_login_otp!(code)
      remember_requested = ActiveModel::Type::Boolean.new.cast(session.delete(:pending_otp_remember_me))
      # Prevent session fixation on successful OTP verification.
      reset_session

      sign_in(resource_name, @pending_user)
      remember_me(@pending_user) if remember_requested && devise_mapping.rememberable?

      redirect_to after_sign_in_path_for(@pending_user), notice: "Logged in successfully."
    else
      flash.now[:alert] = "Invalid or expired verification code."
      render :verify_otp, status: :unprocessable_entity
    end
  end

  def cancel_otp_login
    session.delete(:pending_otp_user_id)
    session.delete(:pending_otp_remember_me)
    sign_out(resource_name) if user_signed_in?

    self.resource = resource_class.new
    clean_up_passwords(resource)
    render :new, status: :ok
  end

  # POST /users/verify_otp/resend — send another login OTP after cooldown (see User#login_otp_resend_wait_seconds).
  def resend_otp
    if @pending_user.login_otp_locked?
      redirect_to users_verify_otp_path, alert: "Too many failed attempts. Please wait and try again."
      return
    end

    wait = @pending_user.login_otp_resend_wait_seconds
    if wait.positive?
      redirect_to users_verify_otp_path, alert: "Please wait #{wait} seconds before requesting a new code."
      return
    end

    code = @pending_user.generate_login_otp!
    # Queue resend mail to avoid blocking the response.
    UserMailer.login_otp_email(@pending_user, code).deliver_later

    redirect_to users_verify_otp_path, notice: "A new verification code has been sent to your email."
  end

  private

  def ensure_pending_otp_user!
    @pending_user = User.find_by(id: session[:pending_otp_user_id])

    return if @pending_user

    redirect_to new_user_session_path, alert: "Your login session expired. Please sign in again."
  end
end
