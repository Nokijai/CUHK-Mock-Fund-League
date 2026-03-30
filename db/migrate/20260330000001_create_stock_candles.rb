class CreateStockCandles < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_candles do |t|
      t.string :symbol, null: false
      t.string :interval, null: false
      t.datetime :candle_at, null: false

      t.decimal :open, precision: 15, scale: 4
      t.decimal :high, precision: 15, scale: 4
      t.decimal :low, precision: 15, scale: 4
      t.decimal :close, precision: 15, scale: 4
      t.decimal :volume, precision: 20, scale: 2

      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :stock_candles, [ :symbol, :interval, :candle_at ],
      unique: true,
      name: "index_stock_candles_on_symbol_interval_candle_at"
    add_index :stock_candles, [ :symbol, :interval ]
    add_index :stock_candles, :candle_at
  end
end

