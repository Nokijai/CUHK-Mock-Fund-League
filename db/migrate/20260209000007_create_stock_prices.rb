class CreateStockPrices < ActiveRecord::Migration[8.0]
  def change
    create_table :stock_prices do |t|
      t.string :symbol, null: false
      t.decimal :price, precision: 15, scale: 4
      t.timestamps
    end
    add_index :stock_prices, :symbol, unique: true
  end
end
