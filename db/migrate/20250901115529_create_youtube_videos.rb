class CreateYoutubeVideos < ActiveRecord::Migration[8.0]
  def change
    create_table :youtube_videos do |t|
      t.references :place, null: false, foreign_key: true
      t.string :video_id, null: false
      t.text :title
      t.text :description
      t.string :thumbnail_url
      t.string :duration
      t.integer :view_count
      t.datetime :published_at
      t.json :video_data
      t.boolean :visible, default: true
      t.integer :sort_order, default: 0

      t.timestamps
    end

    add_index :youtube_videos, [ :place_id, :video_id ], unique: true
    add_index :youtube_videos, [ :place_id, :visible ]
    add_index :youtube_videos, [ :place_id, :sort_order ]
  end
end
