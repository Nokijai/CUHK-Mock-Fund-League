class CreatePortfolioSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :portfolio_snapshots do |t|
      t.references :portfolio, null: false, foreign_key: true
      t.decimal :total_value, precision: 15, scale: 2, null: false
      t.decimal :cash_balance, precision: 15, scale: 2
      t.decimal :holdings_value, precision: 15, scale: 2
      t.date :snapshot_date, null: false
      t.timestamps
    end

    add_index :portfolio_snapshots, [ :portfolio_id, :snapshot_date ], unique: true
    add_column :portfolios, :best_rank, :integer
  end
end
