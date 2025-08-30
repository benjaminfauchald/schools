class AddPhotoVisibilityToSchools < ActiveRecord::Migration[8.0]
  def change
    add_column :schools, :photo_visibility_settings, :json, default: {}
    
    # Add GIN index for JSON operations (requires jsonb)
    reversible do |dir|
      dir.up do
        execute "ALTER TABLE schools ALTER COLUMN photo_visibility_settings TYPE jsonb USING photo_visibility_settings::jsonb"
        add_index :schools, :photo_visibility_settings, using: :gin
      end
      
      dir.down do
        remove_index :schools, :photo_visibility_settings
        execute "ALTER TABLE schools ALTER COLUMN photo_visibility_settings TYPE json USING photo_visibility_settings::json"
      end
    end
  end
end
