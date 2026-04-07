class RefactorUserAuthenticationFields < ActiveRecord::Migration[8.1]
  def change
    # Remove the old name column since username already exists
    # (username was added in a previous migration but not documented in schema.rb)
    remove_column :users, :name, :string if column_exists?(:users, :name)

    # Rename login_otp_* fields to signup_otp_* for clarity
    # Since we're moving email verification from login to signup
    # Check if columns exist before renaming (in case migration was run manually)
    if column_exists?(:users, :login_otp_digest)
      rename_column :users, :login_otp_digest, :signup_otp_digest
    end

    if column_exists?(:users, :login_otp_sent_at)
      rename_column :users, :login_otp_sent_at, :signup_otp_sent_at
    end

    if column_exists?(:users, :login_otp_attempts)
      rename_column :users, :login_otp_attempts, :signup_otp_attempts
    end

    if column_exists?(:users, :login_otp_locked_until)
      rename_column :users, :login_otp_locked_until, :signup_otp_locked_until
    end

    # Rename indexes for the renamed columns (check if old index exists)
    if index_exists?(:users, :login_otp_sent_at, name: :index_users_on_login_otp_sent_at)
      rename_index :users, :index_users_on_login_otp_sent_at, :index_users_on_signup_otp_sent_at
    end

    if index_exists?(:users, :login_otp_locked_until, name: :index_users_on_login_otp_locked_until)
      rename_index :users, :index_users_on_login_otp_locked_until, :index_users_on_signup_otp_locked_until
    end
  end
end
