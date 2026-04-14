class StockPrice < ApplicationRecord
  # Case-insensitive substring match on ticker symbol (Nestak/seeded rows in DB).
  # Use only when the search string is non-blank; aligns with StockPriceService#search.
  scope :matching_query, ->(q) {
    query = q.to_s.strip
    safe_query = ActiveRecord::Base.sanitize_sql_like(query)
    compact_chars = safe_query.delete(" ")
    token_joined = safe_query.split.join("%")

    patterns = [
      "%#{safe_query}%",
      ("%#{compact_chars.chars.join('%')}%" if compact_chars.present?),
      ("%#{token_joined}%" if token_joined.present?)
    ].compact.uniq

    symbol_column = arel_table[:symbol]
    predicates = patterns.map { |pattern| symbol_column.matches(pattern, nil, false) }
    predicates.reduce { |left, right| left.or(right) }.yield_self { |predicate| where(predicate) }
  }
end
