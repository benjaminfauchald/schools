class AddMissingOsmFieldsToPoints < ActiveRecord::Migration[8.0]
  def change
    # Category fields
    add_column :points, :shop, :string
    add_column :points, :tourism, :string
    add_column :points, :leisure, :string
    add_column :points, :office, :string
    add_column :points, :craft, :string
    add_column :points, :healthcare, :string
    add_column :points, :emergency, :string
    add_column :points, :public_transport, :string
    
    # Name variations
    add_column :points, :name_en, :string
    add_column :points, :name_th, :string
    add_column :points, :alt_name, :string
    add_column :points, :official_name, :string
    
    # Operating information
    add_column :points, :opening_hours, :text
    
    # Transportation
    add_column :points, :highway, :string
    add_column :points, :railway, :string
    add_column :points, :aeroway, :string
    add_column :points, :waterway, :string
    
    # Natural and land use
    add_column :points, :natural, :string
    add_column :points, :landuse, :string
    
    # Building information
    add_column :points, :building, :string
    add_column :points, :building_levels, :integer
    
    # Business specific
    add_column :points, :cuisine, :string
    add_column :points, :brand, :string
    add_column :points, :network, :string
    
    # Physical characteristics
    add_column :points, :ele, :integer # elevation
    
    # Add indexes for commonly queried fields
    add_index :points, :shop
    add_index :points, :tourism
    add_index :points, :leisure
    add_index :points, :cuisine
    add_index :points, :brand
    add_index :points, :building
    add_index :points, :highway
    add_index :points, :natural
    add_index :points, :name_en
    add_index :points, :name_th
  end
end