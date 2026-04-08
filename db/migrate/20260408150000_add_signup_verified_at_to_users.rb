class AddSignupVerifiedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    # Used to show "pending" vs "verified" in admin and allow admin approval.
    add_column :users, :signup_verified_at, :datetime
    add_index :users, :signup_verified_at
  end
end

