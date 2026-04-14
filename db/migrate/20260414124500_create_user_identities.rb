class CreateUserIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :user_identities do |t|
      t.references :user, null: false, foreign_key: true

      # Provider identity (unique per provider).
      t.string :provider, null: false
      t.string :uid, null: false

      # Optional metadata for debugging/UI.
      t.string :email
      t.string :name

      t.timestamps
    end

    add_index :user_identities, [ :provider, :uid ], unique: true
    add_index :user_identities, [ :user_id, :provider ], unique: true
  end
end
