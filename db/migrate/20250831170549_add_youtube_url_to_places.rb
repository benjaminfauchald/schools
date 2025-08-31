class AddYoutubeUrlToPlaces < ActiveRecord::Migration[8.0]
  def change
    add_column :places, :youtube_url, :string
  end
end
