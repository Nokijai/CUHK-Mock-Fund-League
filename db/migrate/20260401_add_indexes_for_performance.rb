class AddIndexesForPerformance < ActiveRecord::Migration[7.0]
  def change
    # Stock prices are frequently queried by symbol
    add_index :stock_prices, :symbol, unique: true unless index_exists?(:stock_prices, :symbol)

    # Holdings are queried by symbol for portfolio calculations
    add_index :holdings, :symbol unless index_exists?(:holdings, :symbol)

    # Trades are queried by symbol for history and calculations
    add_index :trades, :symbol unless index_exists?(:trades, :symbol)

    # League memberships unique index prevents duplicate joins
    add_index :league_memberships, [ :user_id, :league_id ], unique: true, name: 'index_league_memberships_on_user_and_league' unless index_exists?(:league_memberships, [ :user_id, :league_id ])
  end
end
