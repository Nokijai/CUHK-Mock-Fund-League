class Admin::DashboardController < Admin::BaseController
  # Keep an explicit action so Zeitwerk eager-load in CI sees a valid constant.
  def index
    redirect_to admin_users_path
  end
end
