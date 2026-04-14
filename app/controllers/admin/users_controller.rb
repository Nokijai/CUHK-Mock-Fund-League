class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [ :edit, :update, :destroy, :approve_signup ]

  def index
    scope = User.all

    @role_filter = params[:role].to_s
    if User::ROLES.include?(@role_filter)
      scope = scope.where(role: @role_filter)
    else
      @role_filter = ""
    end

    @search_query = params[:search].to_s.strip
    if @search_query.present?
      scope = apply_fuzzy_search(scope, [ "username", "email" ], @search_query)
    end

    @users = scope.order(created_at: :desc, id: :desc).page(params[:page]).per(10)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    assign_role_from_params(@user)
    if @user.save
      redirect_to admin_users_path, notice: "User created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    # Remove password params if blank to keep current password
    update_params = user_params
    if update_params[:password].blank?
      update_params.delete(:password)
      update_params.delete(:password_confirmation)
    end

    assign_role_from_params(@user)
    if @user.update(update_params)
      redirect_to admin_users_path, notice: "User updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user == current_user
      redirect_to admin_users_path, alert: "You cannot delete yourself."
    else
      @user.destroy
      redirect_to admin_users_path, notice: "User deleted successfully."
    end
  end

  # POST /admin/users/:id/approve_signup
  def approve_signup
    unless @user.signup_pending?
      redirect_to admin_users_path, notice: "User is already verified."
      return
    end

    @user.approve_signup!
    redirect_to admin_users_path, notice: "User approved (verification bypassed)."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    # Role is assigned explicitly (see assign_role_from_params) to avoid broad mass-assignment.
    params.require(:user).permit(:username, :email, :password, :password_confirmation)
  end

  def assign_role_from_params(user)
    # Keep role assignment explicit to avoid broad mass-assignment surfaces.
    requested_role = params.dig(:user, :role).to_s
    return if requested_role.blank?
    return unless User::ROLES.include?(requested_role)

    user.role = requested_role
  end
end
