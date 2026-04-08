# Repair drift: 20260402000100 may be recorded in schema_migrations while columns are missing
# (e.g. restored DB, manual DDL, or partial migrate). Idempotent so CI and fresh DBs stay safe.
class EnsureLoginOtpColumnsOnUsers < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:users, :login_otp_digest)

    add_column :users, :login_otp_digest, :string
    add_column :users, :login_otp_sent_at, :datetime
    add_column :users, :login_otp_attempts, :integer, default: 0, null: false
    add_column :users, :login_otp_locked_until, :datetime

    add_index :users, :login_otp_sent_at unless index_exists?(:users, :login_otp_sent_at)
    add_index :users, :login_otp_locked_until unless index_exists?(:users, :login_otp_locked_until)
  end

  def down
    return unless column_exists?(:users, :login_otp_digest)

    remove_index :users, :login_otp_sent_at if index_exists?(:users, :login_otp_sent_at)
    remove_index :users, :login_otp_locked_until if index_exists?(:users, :login_otp_locked_until)

    remove_column :users, :login_otp_locked_until
    remove_column :users, :login_otp_attempts
    remove_column :users, :login_otp_sent_at
    remove_column :users, :login_otp_digest
  end
end
