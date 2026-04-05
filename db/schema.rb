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

ActiveRecord::Schema[8.1].define(version: 2026_04_04_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"

  create_table "holdings", force: :cascade do |t|
    t.decimal "average_cost", precision: 15, scale: 4, default: "0.0"
    t.datetime "created_at", null: false
    t.bigint "portfolio_id", null: false
    t.integer "quantity", default: 0, null: false
    t.string "symbol", null: false
    t.datetime "updated_at", null: false
    t.index ["portfolio_id", "symbol"], name: "index_holdings_on_portfolio_id_and_symbol", unique: true
    t.index ["portfolio_id"], name: "index_holdings_on_portfolio_id"
    t.index ["symbol"], name: "index_holdings_on_symbol"
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
    t.datetime "end_date"
    t.string "name", null: false
    t.jsonb "rules", default: {}
    t.datetime "start_date"
    t.decimal "starting_capital", precision: 15, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_leagues_on_name", unique: true
  end

  create_table "portfolio_snapshots", force: :cascade do |t|
    t.decimal "cash_balance", precision: 15, scale: 2
    t.datetime "created_at", null: false
    t.decimal "holdings_value", precision: 15, scale: 2
    t.bigint "portfolio_id", null: false
    t.date "snapshot_date", null: false
    t.decimal "total_value", precision: 15, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["portfolio_id", "snapshot_date"], name: "index_portfolio_snapshots_on_portfolio_id_and_snapshot_date", unique: true
    t.index ["portfolio_id"], name: "index_portfolio_snapshots_on_portfolio_id"
  end

  create_table "portfolios", force: :cascade do |t|
    t.integer "best_rank"
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

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "stock_candles", force: :cascade do |t|
    t.datetime "candle_at", null: false
    t.decimal "close", precision: 15, scale: 4
    t.datetime "created_at", null: false
    t.decimal "high", precision: 15, scale: 4
    t.string "interval", null: false
    t.decimal "low", precision: 15, scale: 4
    t.decimal "open", precision: 15, scale: 4
    t.string "symbol", null: false
    t.datetime "updated_at", null: false
    t.decimal "volume", precision: 20, scale: 2
    t.index ["candle_at"], name: "index_stock_candles_on_candle_at"
    t.index ["symbol", "interval", "candle_at"], name: "index_stock_candles_on_symbol_interval_candle_at", unique: true
    t.index ["symbol", "interval"], name: "index_stock_candles_on_symbol_and_interval"
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
    t.string "order_type", default: "market", null: false
    t.bigint "portfolio_id", null: false
    t.decimal "price", precision: 15, scale: 4, null: false
    t.integer "quantity", null: false
    t.string "symbol", null: false
    t.string "trade_type", null: false
    t.datetime "updated_at", null: false
    t.index ["order_type", "executed_at"], name: "index_trades_on_order_type_and_executed_at"
    t.index ["portfolio_id", "executed_at"], name: "index_trades_on_portfolio_id_and_executed_at"
    t.index ["portfolio_id"], name: "index_trades_on_portfolio_id"
    t.index ["symbol"], name: "index_trades_on_symbol"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "user"
    t.datetime "updated_at", null: false
    t.string "username"
    t.string "signup_otp_digest"
    t.datetime "signup_otp_sent_at"
    t.integer "signup_otp_attempts", default: 0, null: false
    t.datetime "signup_otp_locked_until"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["signup_otp_locked_until"], name: "index_users_on_signup_otp_locked_until"
    t.index ["signup_otp_sent_at"], name: "index_users_on_signup_otp_sent_at"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "holdings", "portfolios"
  add_foreign_key "league_memberships", "leagues"
  add_foreign_key "league_memberships", "users"
  add_foreign_key "portfolio_snapshots", "portfolios"
  add_foreign_key "portfolios", "leagues"
  add_foreign_key "portfolios", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "trades", "portfolios"
end
