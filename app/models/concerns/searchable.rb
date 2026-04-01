# Searchable concern for models that need search and pagination
module Searchable
  extend ActiveSupport::Concern
  
  class_methods do
    def search_and_paginate(query, search_fields, page: 1, per_page: 10)
      scope = all
      
      if query.present?
        search_term = "%#{query}%"
        conditions = search_fields.map { |field| "#{field} ILIKE ?" }.join(" OR ")
        values = Array.new(search_fields.size, search_term)
        scope = scope.where(conditions, *values)
      end
      
      scope.order(created_at: :desc).page(page).per(per_page)
    end
  end
end
