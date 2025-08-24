if Rails.env.development?
  ViewComponent::Base.config.preview_paths = [] unless ViewComponent::Base.config.preview_paths
  ViewComponent::Base.config.preview_paths << Rails.root.join("spec/components/previews")
  ViewComponent::Base.config.show_previews_source = true
end

ViewComponent::Base.config.instrumentation_enabled = true