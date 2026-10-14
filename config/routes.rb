Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Dev-only browser console; never routed in production.
  root "dev/console#show" unless Rails.env.production?

  namespace :finance do
    resources :accounts
    resources :transfers, only: %i[index create destroy]
    resources :categories
    resources :expenses
    resources :transactions do
      member do
        post :reconcile
        post :confirm
        post :ignore
      end
    end
  end
end
