class AddVideoVisibilityToSchools < ActiveRecord::Migration[8.0]
  def change
    add_column :schools, :video_visibility_settings, :jsonb, default: {}
  end
end
