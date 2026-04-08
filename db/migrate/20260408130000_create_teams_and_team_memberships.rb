class CreateTeamsAndTeamMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :teams do |t|
      t.references :league, null: false, foreign_key: true
      t.string :name, null: false
      t.string :password_digest, null: false
      # Counter cache to keep "full?" checks cheap in UI and validations.
      t.integer :team_memberships_count, null: false, default: 0
      t.timestamps
    end

    add_index :teams, [ :league_id, :name ], unique: true

    create_table :team_memberships do |t|
      t.references :team, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      # Denormalized for constraints + quick "already in a team for this league" checks.
      t.references :league, null: false, foreign_key: true
      t.datetime :joined_at
      t.timestamps
    end

    add_index :team_memberships, [ :league_id, :user_id ], unique: true
    add_index :team_memberships, [ :team_id, :user_id ], unique: true
  end
end

