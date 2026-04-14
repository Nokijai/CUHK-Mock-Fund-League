class AddLevelProtectedToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :level_protected, :boolean, default: false, null: false
  end
end
