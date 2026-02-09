class CreateLeagueMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :league_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :league, null: false, foreign_key: true
      t.datetime :joined_at

      t.timestamps
    end
    add_index :league_memberships, [:user_id, :league_id], unique: true
  end
end
