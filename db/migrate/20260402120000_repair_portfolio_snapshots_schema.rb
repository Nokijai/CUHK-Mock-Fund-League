class RepairPortfolioSnapshotsSchema < ActiveRecord::Migration[8.1]
  def up
    # Repair local/CI databases that missed this table due schema drift.
    create_table :portfolio_snapshots, if_not_exists: true do |t|
      t.references :portfolio, null: false
      t.decimal :total_value, precision: 15, scale: 2, null: false
      t.decimal :cash_balance, precision: 15, scale: 2
      t.decimal :holdings_value, precision: 15, scale: 2
      t.date :snapshot_date, null: false
      t.timestamps
    end

    add_index :portfolio_snapshots, [ :portfolio_id, :snapshot_date ],
      unique: true,
      if_not_exists: true
    add_foreign_key :portfolio_snapshots, :portfolios unless foreign_key_exists?(:portfolio_snapshots, :portfolios)

    # Keep portfolios schema aligned with code that tracks historical ranking.
    add_column :portfolios, :best_rank, :integer unless column_exists?(:portfolios, :best_rank)
  end

  def down
    # This is a safety/repair migration; avoid destructive rollback by default.
    remove_column :portfolios, :best_rank if column_exists?(:portfolios, :best_rank)
    return unless table_exists?(:portfolio_snapshots)

    remove_foreign_key :portfolio_snapshots, :portfolios if foreign_key_exists?(:portfolio_snapshots, :portfolios)
    remove_index :portfolio_snapshots, column: [ :portfolio_id, :snapshot_date ] if index_exists?(:portfolio_snapshots, [ :portfolio_id, :snapshot_date ])
    drop_table :portfolio_snapshots
  end
end
