Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

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
