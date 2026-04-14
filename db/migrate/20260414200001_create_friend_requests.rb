class CreateFriendRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :friend_requests do |t|
      t.bigint :sender_id, null: false
      t.bigint :receiver_id, null: false
      t.string :status, null: false, default: "pending"
      t.timestamps
    end

    add_index :friend_requests, [:sender_id, :receiver_id], unique: true
    add_index :friend_requests, [:receiver_id, :status]
    add_foreign_key :friend_requests, :users, column: :sender_id
    add_foreign_key :friend_requests, :users, column: :receiver_id
  end
end
