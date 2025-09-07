class RemoveGeomFromSchools < ActiveRecord::Migration[8.0]
  def change
    # Remove the redundant geometry column, keeping only geography
    remove_index :schools, :geom if index_exists?(:schools, :geom)
    remove_column :schools, :geom, :geometry, limit: { srid: 4326, type: "geometry" }
  end
end
