source "https://rubygems.org"

gem "ostruct", "0.6.3"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2", ">= 8.0.2.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

gem "rake", "13.1.0"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# Facebook API integration
gem "koala", "~> 3.5"

# Download and process images
gem "down", "~> 5.0"

# Document processing with Apache Tika (yomu2 is a maintained fork)
gem "yomu2", "~> 0.3.2"

# Vector database support for AI integration
gem "pgvector", "~> 0.3.2"

# HTTP client for API requests
gem "httparty", "~> 0.21"

# AWS SDK for S3 backup uploads
gem "aws-sdk-s3", "~> 1.143"



gem "rgeo"
gem "rgeo-activerecord"

gem "administrate"
gem "devise"
gem "omniauth"
gem "omniauth-facebook"
gem "omniauth-rails_csrf_protection"
gem "view_component"
gem "foreman"
gem "sentry-ruby"
gem "sentry-rails"

# gem 'iso3166'
gem "countries"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false
  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
  # Fake data generation for testing
  gem "faker", "~> 3.2"
  # Load environment variables from .env file
  gem "dotenv-rails"
  # Development debugging tools
  gem "pry-byebug"
  # HTTP request mocking
  gem "webmock", "~> 3.18"
end

group :development do
  # File watching and auto-testing
  gem "better_html"
  gem "erb_lint"
  gem "guard"
  gem "guard-rspec"
  gem "listen"          # file watcher (uses macOS FSEvents)
  gem "terminal-notifier-guard"
  gem "claude_swarm", "0.3.8"
  gem "claude-on-rails"
end

group :test do
  # RSpec testing framework
  gem "rspec-rails", "~> 6.0"

  # Test data factories
  gem "factory_bot_rails", "~> 6.2"
  # Matchers for common Rails functionality
  gem "shoulda-matchers", "~> 5.3"
  # System testing with browser automation
  gem "capybara", "~> 3.39"
  gem "cuprite", "~> 0.15"  # Headless Chrome driver
  # Database cleaning between tests
  gem "database_cleaner-active_record", "~> 2.1"
  # Rails controller testing for assigns() support in request specs
  gem "rails-controller-testing"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

gem "activerecord-postgis-adapter", "~> 11.0"

# Pagination
gem "kaminari"

gem "letter_opener", "~> 1.10", group: :development
