Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations",
    # OAuth callbacks live under Users::OmniauthCallbacksController.
    omniauth_callbacks: "users/omniauth_callbacks"
  }

  devise_scope :user do
    # Login: password then email OTP (see Users::SessionsController).
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

  # OAuth onboarding: pick a username before entering the app.
  get "users/onboarding/username", to: "users/onboarding#edit_username", as: :edit_users_onboarding_username
  patch "users/onboarding/username", to: "users/onboarding#update_username", as: :users_onboarding_username

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#dashboard"

  # User profile
  get "profile", to: "profiles#show", as: :profile

  # Bookmark / cache may still request /trading; redirect to real nested trade URL.
  get "trading", to: "home#trading_redirect", as: :trading
  get "leaderboard", to: "leaderboards#index", as: :leaderboard

  # Admin namespace
  namespace :admin do
    root "users#index"
    resources :users do
      # Allow admins to approve a pending signup (bypass email OTP).
      post "approve_signup", on: :member
    end
    resources :leagues do
      # Admin team management for team-mode leagues (remove users from teams).
      resources :teams, only: [] do
        resources :memberships, controller: "team_memberships", only: [ :destroy ]
      end
    end
  end

  resources :leagues do
    get :refresh, on: :collection
    get "leaderboard", to: "leaderboards#show", as: :leaderboard
    # Team-mode leagues: users join by selecting a team (with password) instead of direct league join.
    resources :teams, controller: "league_teams", only: [ :create, :destroy ] do
      post "join", to: "team_memberships#create"
    end
  end
  resources :league_memberships, only: [ :index, :create, :destroy ]

  # Friendships & friend requests
  resources :friendships, only: [ :index, :destroy ] do
    collection do
      get :search
    end
  end
  resources :friend_requests, only: [ :index, :create ] do
    member do
      patch :accept
      patch :decline
    end
  end

  # Chat messages
  resources :messages, only: [ :create ] do
    collection do
      get :world
      get :team_list
      get "team_conversation/:team_id", action: :team_conversation, as: :team_conversation
      get "conversation/:friend_id", action: :conversation, as: :conversation
      get :friends_list
    end
  end

  resources :portfolios, only: [ :show ] do
    resources :trades, only: [ :index, :new, :create, :show ]
  end

  get "stocks/search", to: "stocks#search"
  get "stocks/:symbol", to: "stocks#show", as: :stock
  # Ticker news feed (external API, cached). HTML view uses this indirectly too.
  get "stocks/:symbol/news", to: "stocks#news", as: :stock_news

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
