class AddSkipLoginOtpToUsers < ActiveRecord::Migration[8.1]
  def change
    # When true, the user can log in without login OTP (admin-approved users).
    add_column :users, :skip_login_otp, :boolean, default: false, null: false
    add_index :users, :skip_login_otp
  end
end
