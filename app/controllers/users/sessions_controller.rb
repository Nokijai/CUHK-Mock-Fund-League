class Users::SessionsController < Devise::SessionsController
  skip_before_action :authenticate_user!, only: %i[new create verify_otp otp_authenticate cancel_otp_login]
  before_action :ensure_pending_otp_user!, only: %i[verify_otp otp_authenticate]

  def create
    email = sign_in_params[:email].to_s.strip.downcase
    password = sign_in_params[:password].to_s
    user = User.find_for_authentication(email: email)

    unless user&.valid_password?(password)
      self.resource = resource_class.new(sign_in_params)
      flash.now[:alert] = "Invalid email or password."
      clean_up_passwords(resource)
      render :new, status: :unprocessable_entity
      return
    end

    code = user.generate_login_otp!
    UserMailer.login_otp_email(user, code).deliver_now

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
      session.delete(:pending_otp_user_id)

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

  private

  def ensure_pending_otp_user!
    @pending_user = User.find_by(id: session[:pending_otp_user_id])

    return if @pending_user

    redirect_to new_user_session_path, alert: "Your login session expired. Please sign in again."
  end
end
