class AddCreatorToLeagues < ActiveRecord::Migration[8.1]
  def change
    # League "leader" = the user who created the league.
    # Nullable for existing leagues created before this column existed.
    # add_reference adds an index by default; no need to add another one.
    add_reference :leagues, :creator, foreign_key: { to_table: :users }, null: true
  end
end
