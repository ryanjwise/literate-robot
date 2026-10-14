Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Dev-only browser console; never routed in production.
  root "dev/console#show" unless Rails.env.production?

  namespace :finance do
    resources :accounts
    resources :transfers, only: %i[index create destroy] do
      get :needed, on: :collection
    end
    get :forecast, to: "forecasts#show"
    post "pull/up", to: "pulls#up"
    resources :categories
    resources :expenses
    resources :merchants
    resources :transactions do
      collection { post :confirm_auto }
      member do
        post :reconcile
        post :confirm
        post :ignore
      end
    end
  end
end
