class StockPrice < ApplicationRecord
  # Case-insensitive substring match on ticker symbol (Nestak/seeded rows in DB).
  # Use only when the search string is non-blank; aligns with StockPriceService#search.
  scope :matching_query, ->(q) {
    where("symbol ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(q.to_s.strip)}%")
  }
end
