Rails.application.routes.draw do
  # devise_for :admins
  namespace :admin do
      resources :places
      resources :points

      root to: "places#index"
    end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  
  # Root route for landing page
  root 'application#index'
  
  # Onboarding flow
  get 'onboarding', to: 'onboarding#index'
  post 'onboarding/complete', to: 'onboarding#complete'

  # Location management endpoints
  namespace :api do
    namespace :v1 do
      post 'location/validate', to: 'location#validate'
      post 'location/geocode', to: 'location#geocode'
      get 'places/nearby', to: 'places#nearby'
    end
  end

  # Public places routes
  resources :places, only: [:show]

  # Settings page for location management
  get 'settings', to: 'settings#index'
  patch 'settings/location', to: 'settings#update_location'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
