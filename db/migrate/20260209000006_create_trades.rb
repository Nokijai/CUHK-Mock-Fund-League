class CreateTrades < ActiveRecord::Migration[8.0]
  def change
    create_table :trades do |t|
      t.references :portfolio, null: false, foreign_key: true
      t.string :symbol, null: false
      t.string :trade_type, null: false
      t.integer :quantity, null: false
      t.decimal :price, precision: 15, scale: 4, null: false
      t.datetime :executed_at

      t.timestamps
    end
    add_index :trades, [:portfolio_id, :executed_at]
  end
end
