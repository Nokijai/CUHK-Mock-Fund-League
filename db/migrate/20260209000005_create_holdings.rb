class CreateHoldings < ActiveRecord::Migration[8.0]
  def change
    create_table :holdings do |t|
      t.references :portfolio, null: false, foreign_key: true
      t.string :symbol, null: false
      t.integer :quantity, null: false, default: 0
      t.decimal :average_cost, precision: 15, scale: 4, default: 0

      t.timestamps
    end
    add_index :holdings, [ :portfolio_id, :symbol ], unique: true
  end
end
