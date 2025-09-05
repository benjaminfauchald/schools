class AddSourceToMediaItems < ActiveRecord::Migration[8.0]
  def change
    add_column :media_items, :source, :string, default: 'admin_upload'
    add_index :media_items, [:place_id, :kind, :source]
    
    # Update existing records based on their kind
    reversible do |dir|
      dir.up do
        # Set existing campus_photo records to google_places
        execute "UPDATE media_items SET source = 'google_places' WHERE kind = 'campus_photo'"
        
        # Update campus_photo to photo for unified photo management
        execute "UPDATE media_items SET kind = 'photo' WHERE kind = 'campus_photo'"
      end
      
      dir.down do
        # Revert photo back to campus_photo for google_places source
        execute "UPDATE media_items SET kind = 'campus_photo' WHERE kind = 'photo' AND source = 'google_places'"
      end
    end
  end
end
