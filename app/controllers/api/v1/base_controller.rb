module Api
  module V1
    class BaseController < ApplicationController
      # API requests come from curl/Postman/frontend — no browser CSRF token.
      # Null session means the session is emptied instead of raising an error.
      protect_from_forgery with: :null_session
      skip_before_action :set_terminal_nav_context
    end
  end
end
