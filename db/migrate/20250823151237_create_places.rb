class CreatePlaces < ActiveRecord::Migration[8.0]
  def change
    create_table :places do |t|
      # Reference to the Point (OSM data)
      t.references :point, null: true, foreign_key: true
      
      # Basic Google Places identifiers
      t.string :place_id, null: false, index: { unique: true }
      t.string :google_place_id # Sometimes different from place_id
      
      # Basic information
      t.string :name
      t.text :formatted_address
      t.string :vicinity
      t.string :business_status
      t.decimal :rating, precision: 2, scale: 1
      t.integer :user_ratings_total
      t.integer :price_level
      
      # Location data
      t.decimal :lat, precision: 10, scale: 6
      t.decimal :lng, precision: 10, scale: 6
      t.geometry :location, geographic: true
      
      # Contact information
      t.string :formatted_phone_number
      t.string :international_phone_number
      t.string :website
      t.string :url # Google Maps URL
      
      # Business hours
      t.json :opening_hours
      t.json :current_opening_hours
      t.json :secondary_opening_hours
      
      # Categories and types
      t.json :types # Array of place types
      t.string :icon
      t.string :icon_background_color
      t.string :icon_mask_base_uri
      
      # Address components
      t.json :address_components
      t.string :plus_code_compound_code
      t.string :plus_code_global_code
      
      # Reviews and photos
      t.json :reviews
      t.json :photos
      
      # Additional details
      t.text :editorial_summary
      t.json :geometry_data # Full geometry object
      t.boolean :permanently_closed
      t.string :reference
      t.string :scope
      t.integer :utc_offset
      
      # Accessibility and amenities
      t.boolean :wheelchair_accessible_entrance
      t.json :amenities # For various amenity flags
      
      # Raw API response for debugging
      t.json :raw_api_response
      
      # Metadata
      t.datetime :last_fetched_at
      t.string :api_status # 'OK', 'NOT_FOUND', 'ERROR', etc.
      t.text :error_message
      
      t.timestamps
    end
    
    # Additional indexes for common queries
    add_index :places, :name
    add_index :places, :business_status
    add_index :places, :rating
    add_index :places, [:lat, :lng]
    add_index :places, :last_fetched_at
    add_index :places, :api_status
  end
end