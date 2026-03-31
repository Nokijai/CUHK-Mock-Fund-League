class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [ :edit, :update, :destroy ]

  def index
    @users = User.search_and_paginate(
      params[:search],
      %w[name email],
      page: params[:page],
      per_page: 10
    )
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

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end

  def assign_role_from_params(user)
    # Keep role assignment explicit to avoid broad mass-assignment surfaces.
    requested_role = params.dig(:user, :role).to_s
    return if requested_role.blank?
    return unless User::ROLES.include?(requested_role)

    user.role = requested_role
  end
end
