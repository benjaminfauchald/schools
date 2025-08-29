class AddFacebookDataToSchools < ActiveRecord::Migration[8.0]
  def change
    add_column :schools, :facebook_content, :jsonb
    add_column :schools, :facebook_last_fetched, :datetime
    add_column :schools, :facebook_profile_picture_url, :string
    add_column :schools, :facebook_cover_photo_url, :string
    
    add_index :schools, :facebook_content, using: :gin
  end
end