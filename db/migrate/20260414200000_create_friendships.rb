class CreateFriendships < ActiveRecord::Migration[8.1]
  def change
    create_table :friendships do |t|
      t.bigint :user_id, null: false
      t.bigint :friend_id, null: false
      t.timestamps
    end

    add_index :friendships, [:user_id, :friend_id], unique: true
    add_index :friendships, :friend_id
    add_foreign_key :friendships, :users, column: :user_id
    add_foreign_key :friendships, :users, column: :friend_id
  end
end
