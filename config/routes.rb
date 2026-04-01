Rails.application.routes.draw do
  devise_for :users

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
      # League API endpoints used by frontend/API clients.
      resources :leagues, only: [ :index, :show, :create, :update, :destroy ] do
        member do
          post :join
          delete :leave
          get :leaderboard
        end
      end
      resources :trades, only: [ :create ]
      get "stock_prices/:symbol", to: "stock_prices#show", as: :stock_price
    end
  end
end
