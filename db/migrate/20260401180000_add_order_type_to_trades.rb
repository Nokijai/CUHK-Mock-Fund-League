class AddOrderTypeToTrades < ActiveRecord::Migration[8.1]
  def change
    # Distinguish immediate market execution vs pending/triggered limit orders.
    add_column :trades, :order_type, :string, null: false, default: "market"
    add_index :trades, [ :order_type, :executed_at ]
  end
end
