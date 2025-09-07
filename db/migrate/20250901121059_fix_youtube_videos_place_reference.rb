class FixYoutubeVideosPlaceReference < ActiveRecord::Migration[8.0]
  def up
    # Remove old foreign key constraint
    remove_foreign_key :youtube_videos, :schools if foreign_key_exists?(:youtube_videos, :schools)

    # Remove old indexes
    remove_index :youtube_videos, :school_id if index_exists?(:youtube_videos, :school_id)

    # Add place_id column
    add_reference :youtube_videos, :place, null: false, foreign_key: true

    # Migrate data from school_id to place_id by joining with schools table
    execute <<-SQL
      UPDATE youtube_videos#{' '}
      SET place_id = schools.place_id#{' '}
      FROM schools#{' '}
      WHERE youtube_videos.school_id = schools.id#{' '}
      AND schools.place_id IS NOT NULL
    SQL

    # Remove school_id column
    remove_column :youtube_videos, :school_id

    # Add new indexes
    add_index :youtube_videos, [ :place_id, :video_id ], unique: true
    add_index :youtube_videos, [ :place_id, :visible ]
    add_index :youtube_videos, [ :place_id, :sort_order ]
  end

  def down
    # Remove place-based indexes
    remove_index :youtube_videos, [ :place_id, :video_id ] if index_exists?(:youtube_videos, [ :place_id, :video_id ])
    remove_index :youtube_videos, [ :place_id, :visible ] if index_exists?(:youtube_videos, [ :place_id, :visible ])
    remove_index :youtube_videos, [ :place_id, :sort_order ] if index_exists?(:youtube_videos, [ :place_id, :sort_order ])

    # Add school_id column back
    add_reference :youtube_videos, :school, null: false, foreign_key: true

    # Migrate data back from place_id to school_id
    execute <<-SQL
      UPDATE youtube_videos#{' '}
      SET school_id = schools.id#{' '}
      FROM schools#{' '}
      WHERE youtube_videos.place_id = schools.place_id
    SQL

    # Remove place_id column
    remove_foreign_key :youtube_videos, :places
    remove_column :youtube_videos, :place_id

    # Add old index back
    add_index :youtube_videos, :school_id
  end
end
