if Rails.env.development?
  ViewComponent::Base.config.preview_paths = [] unless ViewComponent::Base.config.preview_paths
  ViewComponent::Base.config.preview_paths << Rails.root.join("test/components/previews")
  ViewComponent::Base.config.show_previews_source = true

  # Ensure the preview directory is in the autoload path (check if not frozen)
  preview_path = Rails.root.join("test/components/previews")
  unless Rails.application.config.autoload_paths.frozen? || Rails.application.config.autoload_paths.include?(preview_path)
    Rails.application.config.autoload_paths << preview_path
  end
end

ViewComponent::Base.config.instrumentation_enabled = true
