class SetDefaultUserRole < ActiveRecord::Migration[8.1]
  def up
    # Set default value for role column
    change_column_default :users, :role, from: nil, to: "user"
    
    # Backfill existing users with nil role to "user"
    User.where(role: nil).update_all(role: "user")
    
    # Add index for performance
    add_index :users, :role
  end

  def down
    remove_index :users, :role
    change_column_default :users, :role, from: "user", to: nil
  end
end
