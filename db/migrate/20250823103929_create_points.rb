class CreatePoints < ActiveRecord::Migration[8.0]
  def change
    create_table :points do |t|
      # Core OSM fields
      t.bigint :osm_id, null: false
      t.string :name
      t.string :amenity

      # Geographic fields
      t.decimal :lat, precision: 15, scale: 10, null: false
      t.decimal :lon, precision: 15, scale: 10, null: false
      t.geometry :way, null: false  # PostGIS geometry column

      # Tags (JSON or hstore)
      t.json :tags

      # School-specific fields
      t.string :school_type
      t.string :operator
      t.string :operator_type
      t.string :denomination
      t.string :religion
      t.integer :capacity
      t.string :website
      t.string :phone
      t.string :email
      t.string :grade_range

      # Address fields
      t.string :address
      t.string :addr_housenumber
      t.string :addr_street
      t.string :addr_district
      t.string :addr_subdistrict
      t.string :addr_city
      t.string :addr_province
      t.string :addr_postcode
      t.string :addr_country

      # Additional fields
      t.string :language
      t.string :language_of_instruction
      t.boolean :fee, default: false
      t.string :access
      t.integer :levels
      t.boolean :wheelchair, default: false

      t.timestamps
    end

    # Add indexes
    add_index :points, :osm_id, unique: true
    add_index :points, :amenity
    add_index :points, [ :lat, :lon ]
    add_index :points, :way, using: :gist  # PostGIS spatial index
    add_index :points, :operator_type
    add_index :points, :school_type
    add_index :points, :addr_district
    add_index :points, :addr_city
  end
end
