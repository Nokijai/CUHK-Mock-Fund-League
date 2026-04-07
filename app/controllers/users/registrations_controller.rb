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

      # Validate the resource without saving
      if resource.valid?
        # Generate OTP code without saving user
        code = format("%06d", SecureRandom.random_number(1_000_000))
        otp_digest = generate_otp_digest(resource.email, code)

        # Store everything in session (no database write yet)
        session[:pending_signup] = {
          username: resource.username,
          email: resource.email,
          password: resource.password,
          password_confirmation: resource.password_confirmation,
          otp_digest: otp_digest,
          otp_sent_at: Time.current.to_i,
          otp_attempts: 0
        }

        # Send OTP email
        UserMailer.signup_otp_email(resource, code).deliver_now

        redirect_to users_verify_signup_otp_path, notice: "Please check your email for the verification code."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /users/verify_signup_otp
    def verify_otp
      unless session[:pending_signup]
        redirect_to new_user_registration_path, alert: "No pending signup found."
      end
    end

    # POST /users/otp_authenticate
    def otp_authenticate
      signup_data = session[:pending_signup]

      unless signup_data
        redirect_to new_user_registration_path, alert: "No pending signup found." and return
      end

      # Check if locked
      if otp_locked?(signup_data)
        locked_minutes = ((signup_data["otp_locked_until"] - Time.current.to_i) / 60.0).ceil
        flash.now[:alert] = "Too many failed attempts. Please try again in #{locked_minutes} minutes."
        render :verify_otp, status: :unprocessable_entity and return
      end

      # Check if expired
      if otp_expired?(signup_data)
        flash.now[:alert] = "Verification code has expired. Please request a new one."
        render :verify_otp, status: :unprocessable_entity and return
      end

      code = params[:otp_code]&.strip

      # Verify OTP
      if verify_otp_code(signup_data, code)
        # OTP verified! Now create the user
        user = User.new(
          username: signup_data["username"],
          email: signup_data["email"],
          password: signup_data["password"],
          password_confirmation: signup_data["password_confirmation"]
        )

        if user.save
          session.delete(:pending_signup)
          sign_in(user)
          redirect_to after_sign_in_path_for(user), notice: "Welcome! Your account has been created."
        else
          flash.now[:alert] = "Error creating account: #{user.errors.full_messages.join(', ')}"
          render :verify_otp, status: :unprocessable_entity
        end
      else
        # Failed verification - increment attempts
        signup_data["otp_attempts"] = (signup_data["otp_attempts"] || 0) + 1

        if signup_data["otp_attempts"] >= 5
          signup_data["otp_locked_until"] = 15.minutes.from_now.to_i
        end

        session[:pending_signup] = signup_data
        flash.now[:alert] = "Invalid verification code. Please try again."
        render :verify_otp, status: :unprocessable_entity
      end
    end

    # DELETE /users/cancel_otp_signup
    def cancel_otp_signup
      session.delete(:pending_signup)
      redirect_to new_user_registration_path, notice: "Signup cancelled."
    end

    # POST /users/resend_otp
    def resend_otp
      signup_data = session[:pending_signup]

      unless signup_data
        redirect_to new_user_registration_path, alert: "No pending signup found." and return
      end

      if otp_locked?(signup_data)
        redirect_to users_verify_signup_otp_path, alert: "Too many failed attempts. Please try again later." and return
      end

      unless otp_resend_available?(signup_data)
        wait_seconds = otp_resend_wait_seconds(signup_data)
        redirect_to users_verify_signup_otp_path,
                    alert: "Please wait #{wait_seconds} seconds before requesting a new code." and return
      end

      # Generate new OTP
      code = format("%06d", SecureRandom.random_number(1_000_000))
      signup_data["otp_digest"] = generate_otp_digest(signup_data["email"], code)
      signup_data["otp_sent_at"] = Time.current.to_i
      signup_data["otp_attempts"] = 0
      signup_data["otp_locked_until"] = nil

      session[:pending_signup] = signup_data

      # Send email
      temp_user = User.new(email: signup_data["email"], username: signup_data["username"])
      UserMailer.signup_otp_email(temp_user, code).deliver_now

      redirect_to users_verify_signup_otp_path, notice: "A new verification code has been sent to your email."
    end

    private

    def redirect_if_authenticated
      redirect_to root_path if user_signed_in?
    end

    def generate_otp_digest(email, code)
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "#{email}:#{code}")
    end

    def verify_otp_code(signup_data, code)
      return false if code.blank? || signup_data["otp_digest"].blank?

      expected_digest = generate_otp_digest(signup_data["email"], code)
      ActiveSupport::SecurityUtils.secure_compare(signup_data["otp_digest"], expected_digest)
    end

    def otp_expired?(signup_data)
      return true if signup_data["otp_sent_at"].blank?
      Time.at(signup_data["otp_sent_at"]) < 10.minutes.ago
    end

    def otp_locked?(signup_data)
      return false if signup_data["otp_locked_until"].blank?
      Time.at(signup_data["otp_locked_until"]) > Time.current
    end

    def otp_resend_available?(signup_data)
      return true if signup_data["otp_sent_at"].blank?
      # Aligned with User::SIGNUP_OTP_RESEND_COOLDOWN (session-based signup OTP).
      Time.at(signup_data["otp_sent_at"]) <= User::SIGNUP_OTP_RESEND_COOLDOWN.ago
    end

    def otp_resend_wait_seconds(signup_data)
      return 0 if otp_resend_available?(signup_data)
      [ (Time.at(signup_data["otp_sent_at"]) + User::SIGNUP_OTP_RESEND_COOLDOWN - Time.current).ceil, 0 ].max
    end
  end
end
