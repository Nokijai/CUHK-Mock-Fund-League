class Users::SessionsController < Devise::SessionsController
  skip_before_action :authenticate_user!, only: %i[new create]

  def create
    # Get login identifier (can be username or email)
    login = sign_in_params[:email].to_s.strip
    password = sign_in_params[:password].to_s
    
    # Use the custom finder that supports both username and email
    user = User.find_for_database_authentication(email: login)

    unless user&.valid_password?(password)
      self.resource = resource_class.new(sign_in_params)
      flash.now[:alert] = "Invalid username/email or password."
      clean_up_passwords(resource)
      render :new, status: :unprocessable_entity
      return
    end

    # Sign in the user directly (no OTP required)
    sign_in(resource_name, user)
    
    # Handle "remember me" functionality
    remember_me(user) if ActiveModel::Type::Boolean.new.cast(sign_in_params[:remember_me]) && devise_mapping.rememberable?

    redirect_to after_sign_in_path_for(user), notice: "Logged in successfully."
  end

  private

  def remember_me(user)
    user.remember_me!
  end
end
