class AddExperiencePointsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :experience_points, :integer, default: 0, null: false
  end
end
