class CreatePortfolios < ActiveRecord::Migration[8.0]
  def change
    create_table :portfolios do |t|
      t.references :user, null: false, foreign_key: true
      t.references :league, null: false, foreign_key: true
      t.decimal :cash_balance, precision: 15, scale: 2, default: 0
      t.decimal :total_value, precision: 15, scale: 2, default: 0

      t.timestamps
    end
    add_index :portfolios, [ :user_id, :league_id ], unique: true
  end
end
