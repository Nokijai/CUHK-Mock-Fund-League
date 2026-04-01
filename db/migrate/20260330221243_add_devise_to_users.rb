class AddDeviseToUsers < ActiveRecord::Migration[8.1]
  def up
    change_table :users do |t|
      ## Database authenticatable
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable (optional, uncomment if needed)
      # t.integer  :sign_in_count, default: 0, null: false
      # t.datetime :current_sign_in_at
      # t.datetime :last_sign_in_at
      # t.string   :current_sign_in_ip
      # t.string   :last_sign_in_ip
    end

    add_index :users, :reset_password_token, unique: true

    # Remove old password_digest column
    remove_column :users, :password_digest
  end

  def down
    remove_index :users, :reset_password_token
    remove_column :users, :encrypted_password
    remove_column :users, :reset_password_token
    remove_column :users, :reset_password_sent_at
    remove_column :users, :remember_created_at

    add_column :users, :password_digest, :string
  end
end
