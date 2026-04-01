Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations"
  }

  devise_scope :user do
    # Login OTP routes
    get "users/verify_otp", to: "users/sessions#verify_otp", as: :users_verify_otp
    post "users/verify_otp", to: "users/sessions#otp_authenticate", as: :users_otp_authenticate
    get "users/verify_otp/cancel", to: "users/sessions#cancel_otp_login", as: :users_cancel_otp_login
    post "users/verify_otp/resend", to: "users/sessions#resend_otp", as: :users_resend_login_otp

    # Signup OTP routes
    get "users/verify_signup_otp", to: "users/registrations#verify_otp", as: :users_verify_signup_otp
    post "users/verify_signup_otp", to: "users/registrations#otp_authenticate", as: :users_signup_otp_authenticate
    get "users/verify_signup_otp/cancel", to: "users/registrations#cancel_otp_signup", as: :users_cancel_otp_signup
    post "users/verify_signup_otp/resend", to: "users/registrations#resend_otp", as: :users_resend_signup_otp
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#dashboard"

  # Bookmark / cache may still request /trading; redirect to real nested trade URL.
  get "trading", to: "home#trading_redirect", as: :trading

  # Admin namespace
  namespace :admin do
    root "users#index"
    resources :users
    resources :leagues
  end

  resources :leagues do
    get "leaderboard", to: "leaderboards#show", as: :leaderboard
  end
  resources :league_memberships, only: [ :index, :create, :destroy ]

  resources :portfolios, only: [ :show ] do
    resources :trades, only: [ :index, :new, :create, :show ]
  end

  get "stocks/search", to: "stocks#search"
  get "stocks/:symbol", to: "stocks#show", as: :stock

  namespace :api do
    namespace :v1 do
      # League endpoints use REST resources; no verb-like custom member actions.
      resources :leagues, only: [ :index, :show, :create, :update, :destroy ] do
        # POST /api/v1/leagues/:league_id/memberships
        # DELETE /api/v1/leagues/:league_id/memberships/:user_id
        resources :memberships, controller: "league_memberships", only: [ :create, :destroy ], param: :user_id
        # GET /api/v1/leagues/:league_id/leaderboard
        resource :leaderboard, controller: "leaderboards", only: [ :show ]
      end

      # Trades are nested under portfolios so ownership is path-addressable.
      resources :portfolios, only: [] do
        resources :trades, only: [ :create ]
      end

      # Stock quote/candle read endpoint uses the stock symbol as resource id.
      resources :stocks, only: [ :show ], param: :symbol
    end
  end
end
