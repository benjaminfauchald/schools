Rails.application.routes.draw do
  # OmniAuth callbacks must be outside locale scope
  devise_for :users, only: :omniauth_callbacks, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks"
  }

  # Facebook sync endpoint (outside locale scope for JavaScript API calls)
  devise_scope :user do
    post "users/auth/facebook/sync_status", to: "users/omniauth_callbacks#sync_status"
  end

  # Locale-based routing wrapper
  scope "(:locale)", locale: /en|th/ do
  devise_for :users, skip: :omniauth_callbacks, controllers: {
    registrations: "users/registrations",
    confirmations: "users/confirmations",
    sessions: "users/sessions"
  }

  # Additional Devise routes
  devise_scope :user do
    # Add GET route for sign out (for convenience)
    get "/users/sign_out", to: "devise/sessions#destroy"

    # Store school context before Facebook OAuth
    post "users/auth/facebook/store_school", to: "users/omniauth_callbacks#store_school"

    # Mock Facebook authentication for development
    if Rails.env.development?
      get "users/auth/facebook/mock", to: "users/omniauth_callbacks#mock_facebook", as: :mock_facebook_auth
    end
  end

  # Magic Link Authentication
  get "auth/dashboard/:token", to: "magic_links#dashboard", as: :magic_link_dashboard

  # Facebook Webhooks
  get "facebook_webhooks/verify", to: "facebook_webhooks#verify"
  post "facebook_webhooks/delete_data", to: "facebook_webhooks#delete_data"
  post "facebook_webhooks/deauthorize", to: "facebook_webhooks#deauthorize"
  get "facebook_webhooks/deletion_status/:facebook_user_id", to: "facebook_webhooks#deletion_status"

  # Legacy route for delete_data (if already configured in Facebook)
  post "delete_data", to: "facebook_webhooks#delete_data"

  # Direct Claims (auto-creates accounts)
  get "schools/:school_id/claim", to: "direct_claims#new", as: :new_direct_claim
  post "schools/:school_id/claim", to: "direct_claims#create", as: :create_direct_claim
  get "claim/success", to: "direct_claims#success", as: :direct_claim_success

  # Anonymous Claims (legacy - for backward compatibility)
  resources :anonymous_claims, only: [ :new, :create ], param: :token do
    collection do
      get "new/:school_id", to: "anonymous_claims#new", as: :new_for_school
      post "create/:school_id", to: "anonymous_claims#create", as: :create_for_school
    end
  end
  get "claim/:token", to: "anonymous_claims#show", as: :anonymous_claim
  post "claim/:token/complete", to: "anonymous_claims#complete_registration", as: :complete_anonymous_claim

  # School Owner Dashboard
  namespace :school_owner do
    resources :dashboard, only: [ :index ]
    resources :inquiries, only: [ :index, :show, :update ]
    resources :schools, only: [ :index, :show, :edit, :update ] do
      member do
        get :academic_programs
        patch :update_academic_programs
        get :facilities
        patch :update_facilities
        delete "photos/:photo_id", action: :delete_photo, as: :delete_photo
        delete "media_items/:media_item_id", action: :delete_media_item, as: :delete_media_item
        patch :toggle_photo_visibility
        get :fetch_videos
        patch :toggle_video_visibility
        post "youtube_videos/:video_key/generate_transcript", action: :generate_transcript, as: :generate_video_transcript
        patch "youtube_videos/:video_key/toggle_transcript_ai", action: :toggle_transcript_ai, as: :toggle_video_transcript_ai
        post :import_website_data
        get :import_status
        post :upload_document
        delete :delete_document
        patch :toggle_document_ai
        patch :reprocess_document
        get :download_document
        get :ai_chat
        post :ai_chat_message
        get :ai_suggestions
        get :ai_analysis
        get :sources_count
      end
      resources :pages, except: [ :show ] do
        collection do
          post :generate_content
        end
      end
    end
    resources :claims, only: [ :index, :show, :new, :create ] do
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

  devise_for :admin_users, path: "admin", controllers: {
    sessions: "admin/sessions"
  }
  namespace :admin do
      root to: "dashboard#index"
      resources :inquiries, only: [ :index, :show, :update ]
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
      resources :temp_claims, only: [ :index, :show, :edit, :update, :destroy ]
      resources :google_map_imports, only: [ :index, :new, :create ]
    end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Block WordPress scanner routes and other common bot patterns
  get "*path", to: "application#not_found", constraints: lambda { |req|
    req.params[:rest_route].present? ||
    req.path.include?("wp-") ||
    req.path.include?("wordpress") ||
    req.path.include?("xmlrpc.php") ||
    req.path.include?("admin-ajax.php") ||
    req.path.include?(".env") ||
    req.path.include?("config.php") ||
    req.user_agent&.include?("bot") ||
    req.user_agent&.include?("scanner")
  }

  # SEO routes (outside locale scope for universal access)
  get "sitemap.xml", to: "seo#sitemap", format: :xml
  get "robots.txt", to: "seo#robots", format: :text

  # Root route - main school listing with distance filtering
  root "schools#index"

  # Onboarding flow
  get "onboarding", to: "onboarding#index"
  post "onboarding/complete", to: "onboarding#complete"

  # Location management endpoints
  namespace :api do
    namespace :v1 do
      post "location/validate", to: "location#validate"
      post "location/geocode", to: "location#geocode"
      get "places/nearby", to: "places#nearby"
      get "photos/proxy", to: "photos#proxy"
    end
  end

  # Public places routes
  resources :places, only: [ :show ]

  # Schools routes
  resources :schools, only: [ :show ] do
    collection do
      get :filtered, to: "schools#filtered"
      get :search, to: "schools#search"
    end

    member do
      post :ai_chat
    end

    # Nested pages routes for school content
    resources :pages, only: [ :index, :show ], path: "pages"
    # School inquiry contact form
    resources :school_inquiries, only: [ :create ]
  end

  # Settings page for location management
  get "settings", to: "settings#index"
  patch "settings/location", to: "settings#update_location"

  # Terms of Service page
  get "tos", to: "terms#show", as: :terms_of_service

  # Privacy Policy page
  get "privacy-policy", to: "privacy#show", as: :privacy_policy

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
  end # End of locale scope
end
