class AddUsernameToUsers < ActiveRecord::Migration[8.1]
  def change
    # Add username column unless it already exists
    unless column_exists?(:users, :username)
      add_column :users, :username, :string
      add_index :users, :username, unique: true
    end
  end
end
