# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_09_000007) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "holdings", force: :cascade do |t|
    t.decimal "average_cost", precision: 15, scale: 4, default: "0.0"
    t.datetime "created_at", null: false
    t.bigint "portfolio_id", null: false
    t.integer "quantity", default: 0, null: false
    t.string "symbol", null: false
    t.datetime "updated_at", null: false
    t.index ["portfolio_id", "symbol"], name: "index_holdings_on_portfolio_id_and_symbol", unique: true
    t.index ["portfolio_id"], name: "index_holdings_on_portfolio_id"
  end

  create_table "league_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "joined_at"
    t.bigint "league_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["league_id"], name: "index_league_memberships_on_league_id"
    t.index ["user_id", "league_id"], name: "index_league_memberships_on_user_id_and_league_id", unique: true
    t.index ["user_id"], name: "index_league_memberships_on_user_id"
  end

  create_table "leagues", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.date "end_date"
    t.string "name", null: false
    t.jsonb "rules", default: {}
    t.date "start_date"
    t.decimal "starting_capital", precision: 15, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
  end

  create_table "portfolios", force: :cascade do |t|
    t.decimal "cash_balance", precision: 15, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.bigint "league_id", null: false
    t.decimal "total_value", precision: 15, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["league_id"], name: "index_portfolios_on_league_id"
    t.index ["user_id", "league_id"], name: "index_portfolios_on_user_id_and_league_id", unique: true
    t.index ["user_id"], name: "index_portfolios_on_user_id"
  end

  create_table "stock_prices", force: :cascade do |t|
    t.decimal "price", precision: 15, scale: 4
    t.string "symbol", null: false
    t.datetime "updated_at", null: false
    t.index ["symbol"], name: "index_stock_prices_on_symbol", unique: true
  end

  create_table "trades", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "executed_at"
    t.bigint "portfolio_id", null: false
    t.decimal "price", precision: 15, scale: 4, null: false
    t.integer "quantity", null: false
    t.string "symbol", null: false
    t.string "trade_type", null: false
    t.datetime "updated_at", null: false
    t.index ["portfolio_id", "executed_at"], name: "index_trades_on_portfolio_id_and_executed_at"
    t.index ["portfolio_id"], name: "index_trades_on_portfolio_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.string "password_digest"
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "holdings", "portfolios"
  add_foreign_key "league_memberships", "leagues"
  add_foreign_key "league_memberships", "users"
  add_foreign_key "portfolios", "leagues"
  add_foreign_key "portfolios", "users"
  add_foreign_key "trades", "portfolios"
end
