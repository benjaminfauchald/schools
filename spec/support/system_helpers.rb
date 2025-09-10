module SystemHelpers
  # Override school_path to properly handle locale-scoped routes in system tests
  def school_path(school_or_id, options = {})
    if school_or_id.is_a?(ActiveRecord::Base)
      # Always use ID for system tests - more reliable
      "/schools/#{school_or_id.id}"
    else
      "/schools/#{school_or_id}"
    end
  end
end
