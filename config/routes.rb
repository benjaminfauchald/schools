Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: 'users/registrations',
    confirmations: 'users/confirmations'
  }
  
  # Magic Link Authentication
  get 'auth/dashboard/:token', to: 'magic_links#dashboard', as: :magic_link_dashboard
  
  # Direct Claims (auto-creates accounts)
  get 'schools/:school_id/claim', to: 'direct_claims#new', as: :new_direct_claim
  post 'schools/:school_id/claim', to: 'direct_claims#create', as: :create_direct_claim
  get 'claim/success', to: 'direct_claims#success', as: :direct_claim_success
  
  # Anonymous Claims (legacy - for backward compatibility)
  resources :anonymous_claims, only: [:new, :create], param: :token do
    collection do
      get 'new/:school_id', to: 'anonymous_claims#new', as: :new_for_school
      post 'create/:school_id', to: 'anonymous_claims#create', as: :create_for_school
    end
  end
  get 'claim/:token', to: 'anonymous_claims#show', as: :anonymous_claim
  post 'claim/:token/complete', to: 'anonymous_claims#complete_registration', as: :complete_anonymous_claim
  
  # School Owner Dashboard
  namespace :school_owner do
    resources :dashboard, only: [:index]
    resources :schools, only: [:index, :show, :edit, :update] do
      member do
        get :academic_programs
        patch :update_academic_programs
        get :facilities
        patch :update_facilities
        delete 'photos/:photo_id', action: :delete_photo, as: :delete_photo
        patch :toggle_photo_visibility
        get :fetch_videos
        patch :toggle_video_visibility
        post :import_website_data
        get :import_status
      end
      resources :pages, except: [:show] do
        collection do
          post :generate_content
        end
      end
    end
    resources :claims, only: [:index, :show, :new, :create] do
      member do
        get :evidence
      end
    end
    resources :diagnostics, only: [] do
      collection do
        get :schema_info
      end
    end
  end
  
  devise_for :admin_users, path: 'admin', controllers: {
    sessions: 'admin/sessions'
  }
  namespace :admin do
      root to: "dashboard#index"
      resources :places
      resources :points
      resources :schools
      resources :pages
      resources :media_items
      resources :events
      resources :travel_times
      resources :school_claims do
        collection do
          post :bulk_approve
          post :bulk_reject
          post :bulk_revoke
        end
        member do
          patch :approve
          patch :reject
          patch :revoke
        end
      end
      resources :school_fee_schedules
      resources :school_grade_offerings
      resources :taggings
      resources :terms
      resources :audit_logs
      resources :vocabularies
      resources :school_fee_bands
      resources :users
      resources :temp_claims, only: [:index, :show, :edit, :update, :destroy]
      resources :google_map_imports, only: [:index, :new, :create]
    end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  
  # Root route - main school listing with distance filtering
  root 'schools#index'
  
  # Onboarding flow
  get 'onboarding', to: 'onboarding#index'
  post 'onboarding/complete', to: 'onboarding#complete'

  # Location management endpoints
  namespace :api do
    namespace :v1 do
      post 'location/validate', to: 'location#validate'
      post 'location/geocode', to: 'location#geocode'
      get 'places/nearby', to: 'places#nearby'
      get 'photos/proxy', to: 'photos#proxy'
    end
  end

  # Public places routes
  resources :places, only: [:show]

  # Schools routes
  resources :schools, only: [:show] do
    collection do
      get :filtered, to: 'schools#filtered'
      get :search, to: 'schools#search'
    end
    
    # Nested pages routes for school content
    resources :pages, only: [:index, :show], path: 'pages'
    # School inquiry contact form
    resources :school_inquiries, only: [:create]
  end

  # Settings page for location management
  get 'settings', to: 'settings#index'
  patch 'settings/location', to: 'settings#update_location'

  # ViewComponent previews (development only)
  if Rails.env.development?
    mount ViewComponent::Engine, at: "/rails/view_components"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
