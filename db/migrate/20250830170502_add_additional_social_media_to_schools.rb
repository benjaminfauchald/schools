class AddAdditionalSocialMediaToSchools < ActiveRecord::Migration[8.0]
  def change
    add_column :schools, :youtube_url, :string
    add_column :schools, :linkedin_url, :string
    add_column :schools, :twitter_url, :string
    add_column :schools, :instagram_url, :string
  end
end
