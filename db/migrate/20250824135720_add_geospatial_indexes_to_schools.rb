class AddGeospatialIndexesToSchools < ActiveRecord::Migration[8.0]
  def change
    # Composite index for published schools filtering with geospatial queries
    add_index :schools, [ :status, :place_id ], name: 'index_schools_on_status_and_place_id'

    # Index on schools geography for distance calculations (schools have geog column)
    unless index_exists?(:schools, :geog, using: :gist)
      add_index :schools, :geog, using: :gist, name: 'index_schools_on_geog_gist'
    end

    # Spatial index on places lat/lng for distance calculations
    unless index_exists?(:places, [ :lat, :lng ])
      add_index :places, [ :lat, :lng ], name: 'index_places_on_lat_lng'
    end

    # Composite index on places for schools join queries
    add_index :places, [ :id, :lat, :lng ], name: 'index_places_on_id_lat_lng'
  end
end
