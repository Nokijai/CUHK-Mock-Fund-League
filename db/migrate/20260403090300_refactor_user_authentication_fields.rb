class RefactorUserAuthenticationFields < ActiveRecord::Migration[8.1]
  def change
    # Drop legacy display name; usernames are the canonical public handle (see User validations).
    remove_column :users, :name, :string if column_exists?(:users, :name)

    # Note: login_otp_* columns stay for email OTP at sign-in. Signup verification uses session-backed OTP
    # in RegistrationsController until/unless persisted signup_otp_* columns are introduced separately.
  end
end
