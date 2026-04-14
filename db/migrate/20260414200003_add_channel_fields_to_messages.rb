class AddChannelFieldsToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :channel_type, :string, null: false, default: "individual"
    add_column :messages, :team_id, :bigint
    add_column :messages, :league_id, :bigint

    change_column_null :messages, :receiver_id, true

    add_index :messages, [:channel_type, :created_at]
    add_index :messages, [:team_id, :created_at]
    add_index :messages, [:league_id, :created_at]
    add_foreign_key :messages, :teams, column: :team_id
    add_foreign_key :messages, :leagues, column: :league_id
  end
end
