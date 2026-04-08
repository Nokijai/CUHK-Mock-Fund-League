module Users
  class RegistrationsController < Devise::RegistrationsController
    skip_before_action :authenticate_user!, only: [ :new, :create, :verify_otp, :otp_authenticate, :cancel_otp_signup, :resend_otp ]
    before_action :redirect_if_authenticated, only: [ :new, :create, :verify_otp ]

    helper_method :otp_resend_wait_seconds

    # GET /users/sign_up
    def new
      super
    end

    # POST /users
    def create
      build_resource(sign_up_params)

      # Persist signup as "pending" so admins can manage/approve it.
      if resource.save
        code = resource.generate_signup_otp!
        # Queue OTP mail to avoid blocking signup request.
        UserMailer.signup_otp_email(resource, code).deliver_later

        session[:pending_signup_user_id] = resource.id
        redirect_to users_verify_signup_otp_path, notice: "Please check your email for the verification code."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /users/verify_signup_otp
    def verify_otp
      @pending_user = User.find_by(id: session[:pending_signup_user_id])
      unless @pending_user
        redirect_to new_user_registration_path, alert: "No pending signup found."
        return
      end

      unless @pending_user.signup_pending?
        # Admin may approve while the user is on this page; rotate the session before sign-in.
        reset_session
        sign_in(@pending_user)
        redirect_to after_sign_in_path_for(@pending_user), notice: "Welcome! Your account has been created."
      end
    end

    # POST /users/otp_authenticate
    def otp_authenticate
      @pending_user = User.find_by(id: session[:pending_signup_user_id])
      unless @pending_user
        redirect_to new_user_registration_path, alert: "No pending signup found." and return
      end

      unless @pending_user.signup_pending?
        # Admin may approve while the user is on this page; treat as already verified.
        reset_session
        sign_in(@pending_user)
        redirect_to after_sign_in_path_for(@pending_user), notice: "Welcome! Your account has been created."
        return
      end

      code = params[:otp_code].to_s.strip

      if @pending_user.signup_otp_locked?
        flash.now[:alert] = "Too many failed attempts. Please wait and try again."
        render :verify_otp, status: :unprocessable_entity and return
      end

      if @pending_user.signup_otp_expired?
        flash.now[:alert] = "Verification code has expired. Please request a new one."
        render :verify_otp, status: :unprocessable_entity and return
      end

      if @pending_user.verify_signup_otp!(code)
        # Prevent session fixation on successful signup verification.
        reset_session
        sign_in(@pending_user)
        redirect_to after_sign_in_path_for(@pending_user), notice: "Welcome! Your account has been created."
      else
        flash.now[:alert] = "Invalid verification code. Please try again."
        render :verify_otp, status: :unprocessable_entity
      end
    end

    # DELETE /users/cancel_otp_signup
    def cancel_otp_signup
      pending_user = User.find_by(id: session[:pending_signup_user_id])
      session.delete(:pending_signup_user_id)

      # Clean up unverified accounts to avoid accumulating abandoned signups.
      pending_user&.destroy if pending_user&.signup_pending?

      redirect_to new_user_registration_path, notice: "Signup cancelled."
    end

    # POST /users/resend_otp
    def resend_otp
      @pending_user = User.find_by(id: session[:pending_signup_user_id])
      unless @pending_user
        redirect_to new_user_registration_path, alert: "No pending signup found." and return
      end

      unless @pending_user.signup_pending?
        session.delete(:pending_signup_user_id)
        redirect_to new_user_session_path, notice: "Your email is already verified. Please log in."
        return
      end

      if @pending_user.signup_otp_locked?
        redirect_to users_verify_signup_otp_path, alert: "Too many failed attempts. Please try again later." and return
      end

      wait = @pending_user.signup_otp_resend_wait_seconds
      if wait.positive?
        redirect_to users_verify_signup_otp_path, alert: "Please wait #{wait} seconds before requesting a new code." and return
      end

      code = @pending_user.generate_signup_otp!
      # Queue resend mail to avoid blocking the response.
      UserMailer.signup_otp_email(@pending_user, code).deliver_later

      redirect_to users_verify_signup_otp_path, notice: "A new verification code has been sent to your email."
    end

    private

    def redirect_if_authenticated
      redirect_to root_path if user_signed_in?
    end

    def otp_resend_wait_seconds
      pending_user = User.find_by(id: session[:pending_signup_user_id])
      pending_user ? pending_user.signup_otp_resend_wait_seconds : 0
    end
  end
end
