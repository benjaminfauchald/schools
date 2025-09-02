class RepairTranscriptTables < ActiveRecord::Migration[8.0]
  def change
    # Drop existing broken tables first
    drop_table :transcript_segments, if_exists: true
    drop_table :transcripts, if_exists: true
    
    # Create transcripts table
    create_table :transcripts do |t|
      t.references :place, null: false, foreign_key: true
      t.string :video_id, null: false
      t.string :video_title
      t.text :video_description
      t.string :video_url
      t.text :full_transcript
      t.string :language, default: 'en'
      t.integer :duration_seconds
      t.string :status, default: 'pending'
      t.text :processing_error
      t.json :metadata
      t.text :embedding # Store as JSON array for now
      t.datetime :processed_at
      t.timestamps
      
      t.index [:place_id, :video_id], unique: true
      t.index :video_id
      t.index :status
      t.index :processed_at
    end
    
    # Create transcript_segments table
    create_table :transcript_segments do |t|
      t.references :transcript, null: false, foreign_key: true
      t.integer :segment_index, null: false
      t.text :text, null: false
      t.float :start_time
      t.float :end_time
      t.string :speaker
      t.float :confidence
      t.text :embedding # Store as JSON array for now
      t.json :metadata
      t.timestamps
      
      t.index [:transcript_id, :segment_index], unique: true
      t.index :start_time
      t.index :end_time
      t.index :speaker
    end
  end
end
