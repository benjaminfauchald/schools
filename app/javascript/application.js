// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "flowbite"

// Google Maps Service - Centralized loading
import "services/google_maps_service"

// Analytics Service - Mixpanel tracking
import "services/analytics"

// Action Text with Trix editor
import "trix"
import "@rails/actiontext"
