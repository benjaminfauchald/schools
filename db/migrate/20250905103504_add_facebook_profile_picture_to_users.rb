class AddFacebookProfilePictureToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :facebook_profile_picture_url, :string
  end
end
