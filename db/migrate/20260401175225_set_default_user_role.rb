class SetDefaultUserRole < ActiveRecord::Migration[8.1]
  def up
    # Some environments were created before `users.role` existed; ensure the column
    # is present so the rest of the migration (default/backfill/index) is safe.
    unless column_exists?(:users, :role)
      add_column :users, :role, :string
    end

    # Set default value for role column.
    change_column_default :users, :role, from: nil, to: "user"

    # Backfill existing users with nil role to "user"
    User.where(role: nil).update_all(role: "user")

    # Add index for performance
    add_index :users, :role unless index_exists?(:users, :role)
  end

  def down
    remove_index :users, :role if index_exists?(:users, :role)
    change_column_default :users, :role, from: "user", to: nil if column_exists?(:users, :role)
    remove_column :users, :role if column_exists?(:users, :role)
  end
end
