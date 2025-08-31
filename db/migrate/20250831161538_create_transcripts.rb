class CreateTranscripts < ActiveRecord::Migration[8.0]
  def change
    create_table :transcripts do |t|
      t.references :place, null: false, foreign_key: true
      t.string :video_title, null: false
      t.string :video_url
      t.string :youtube_video_id
      t.string :primary_language, default: 'en'
      t.json :available_languages
      t.text :full_transcript_text
      t.column :embedding, :vector, limit: 1536
      t.integer :total_duration_ms
      t.integer :segment_count
      t.datetime :processed_at

      t.timestamps
    end
    
    add_index :transcripts, [:place_id, :youtube_video_id], unique: true
    add_index :transcripts, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end
