class CreateSchools < ActiveRecord::Migration[8.0]
  def change
    # Enable required PostgreSQL extensions
    enable_extension 'citext' unless extension_enabled?('citext')
    enable_extension 'postgis' unless extension_enabled?('postgis')
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')

    create_table :schools do |t|
      # Reference to Google Places data
      t.references :place, null: true, foreign_key: true

      # Identity
      t.string :name, null: false
      t.string :slug, null: false

      # Profile
      t.text :about
      t.integer :founded_year
      t.string :ownership # nonprofit|private|foundation|other

      # Contact (can override or supplement Places data)
      t.string :phone
      t.citext :email
      t.string :website_url
      t.string :admissions_url

      # Location (synced from Places or manual entry)
      t.string :address_line_1
      t.string :address_line_2
      t.string :district
      t.string :province
      t.string :postcode
      t.string :country_code, default: 'TH'

      # Geo fields (synced from Places)
      t.decimal :lat, precision: 10, scale: 6
      t.decimal :lng, precision: 10, scale: 6
      t.geometry :geom, srid: 4326  # Point geometry

      # Operations
      t.decimal :student_teacher_ratio, precision: 4, scale: 2
      t.integer :avg_class_size
      t.boolean :boarding, default: false
      t.boolean :school_bus, default: false
      t.text :language_support_notes

      # Workflow
      t.string :status, default: 'draft' # draft|pending_review|published|suspended
      t.datetime :last_verification_at

      # Optional: Text search vector (maintained by trigger)
      t.tsvector :tsv

      t.timestamps
    end

    # Add geography column separately
    add_column :schools, :geog, :geography, limit: { srid: 4326, type: "point" }

    # Indexes
    add_index :schools, :slug, unique: true
    add_index :schools, :status
    add_index :schools, :district
    add_index :schools, :province
    # Note: place_id index is already created by t.references

    # PostGIS indexes
    add_index :schools, :geog, using: :gist
    add_index :schools, :geom, using: :gist

    # Text search index (if using tsvector)
    add_index :schools, :tsv, using: :gin

    # Trigram indexes for fuzzy search
    add_index :schools, :name, using: :gin, opclass: :gin_trgm_ops
  end
end
