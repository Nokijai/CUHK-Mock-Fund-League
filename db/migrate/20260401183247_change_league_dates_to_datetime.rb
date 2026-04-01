class ChangeLeagueDatesToDatetime < ActiveRecord::Migration[8.1]
  def up
    change_column :leagues, :start_date, :datetime
    change_column :leagues, :end_date, :datetime
  end

  def down
    change_column :leagues, :start_date, :date
    change_column :leagues, :end_date, :date
  end
end
