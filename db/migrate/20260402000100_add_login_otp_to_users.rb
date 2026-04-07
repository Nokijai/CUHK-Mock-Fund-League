class AddLoginOtpToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :login_otp_digest, :string
    add_column :users, :login_otp_sent_at, :datetime
    add_column :users, :login_otp_attempts, :integer, default: 0, null: false
    add_column :users, :login_otp_locked_until, :datetime

    add_index :users, :login_otp_sent_at
    add_index :users, :login_otp_locked_until
  end
end
