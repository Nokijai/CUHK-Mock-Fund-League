class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def up
    # Ensure `users.role` exists for authorization checks and defaulting logic in `User`.
    return if column_exists?(:users, :role)

    add_column :users, :role, :string, default: "user", null: false
    add_index :users, :role unless index_exists?(:users, :role)

    # Backfill any pre-existing rows (defensive: should be covered by null: false + default).
    execute <<~SQL.squish
      UPDATE users
      SET role = 'user'
      WHERE role IS NULL
    SQL
  end

  def down
    remove_index :users, :role if index_exists?(:users, :role)
    remove_column :users, :role if column_exists?(:users, :role)
  end
end
