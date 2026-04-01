Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: "users/sessions" }

  devise_scope :user do
    get "users/verify_otp", to: "users/sessions#verify_otp", as: :users_verify_otp
    post "users/verify_otp", to: "users/sessions#otp_authenticate", as: :users_otp_authenticate
    get "users/verify_otp/cancel", to: "users/sessions#cancel_otp_login", as: :users_cancel_otp_login
    post "users/verify_otp/resend", to: "users/sessions#resend_otp", as: :users_resend_otp
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#dashboard"

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
      resources :trades, only: [ :create ]
      get "stock_prices/:symbol", to: "stock_prices#show", as: :stock_price
    end
  end
end
