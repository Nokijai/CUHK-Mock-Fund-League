# frozen_string_literal: true

# Wipe application rows while keeping the database object and schema (safe for Heroku / RDS).
# Does NOT run `db:drop`. Order respects foreign keys beyond what `db/seeds.rb` covered.
namespace :db do
  desc "Delete all application data (trades, leagues, users, stock prices, …). Keeps schema and Solid Queue tables unless CLEAR_SOLID_QUEUE=1."
  task purge_application_data: :environment do
    # Guard: destructive; require explicit operator intent (any Rails.env, including production).
    if ENV["CONFIRM_DB_PURGE"] != "1"
      abort "db:purge_application_data — set CONFIRM_DB_PURGE=1 to confirm (wipes users, leagues, trades, stock prices, …)."
    end

    ActiveRecord::Base.transaction do
      Trade.delete_all
      Holding.delete_all
      PortfolioSnapshot.delete_all
      TeamMembership.delete_all
      Team.delete_all
      Portfolio.delete_all
      LeagueMembership.delete_all
      # Leagues may reference users via creator_id; clear before deleting users.
      League.update_all(creator_id: nil)
      League.delete_all
      User.delete_all
      StockCandle.delete_all
      StockPrice.delete_all

      if ENV["CLEAR_SOLID_QUEUE"] == "1"
        # Solid Queue: TRUNCATE jobs CASCADE clears execution tables that reference jobs (see db/queue_migrate).
        connection = ActiveRecord::Base.connection
        if connection.data_source_exists?("solid_queue_jobs")
          connection.execute("TRUNCATE TABLE #{connection.quote_table_name('solid_queue_jobs')} RESTART IDENTITY CASCADE")
        end
        %w[solid_queue_recurring_tasks solid_queue_processes solid_queue_pauses solid_queue_semaphores].each do |table|
          next unless connection.data_source_exists?(table)

          connection.execute("TRUNCATE TABLE #{connection.quote_table_name(table)} RESTART IDENTITY CASCADE")
        end
      end
    end

    tables = %w[users leagues portfolios holdings trades stock_prices stock_candles league_memberships portfolio_snapshots teams team_memberships]
    tables.each do |table_name|
      next unless ActiveRecord::Base.connection.data_source_exists?(table_name)

      ActiveRecord::Base.connection.reset_pk_sequence!(table_name)
    rescue StandardError => e
      warn "db:purge_application_data — could not reset PK sequence for #{table_name}: #{e.message}"
    end

    puts "db:purge_application_data — done (CLEAR_SOLID_QUEUE was #{ENV['CLEAR_SOLID_QUEUE'] == '1' ? 'on' : 'off'})."
  end
end
