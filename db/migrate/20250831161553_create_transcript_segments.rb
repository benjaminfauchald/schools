class CreateTranscriptSegments < ActiveRecord::Migration[8.0]
  def change
    create_table :transcript_segments do |t|
      t.references :transcript, null: false, foreign_key: true
      t.text :text, null: false
      t.string :language, default: 'en'
      t.integer :offset_ms, null: false
      t.integer :duration_ms, null: false
      t.integer :sequence_number, null: false
      t.vector :embedding, limit: 1536

      t.timestamps
    end
    
    add_index :transcript_segments, [:transcript_id, :sequence_number], unique: true
    add_index :transcript_segments, :offset_ms
    add_index :transcript_segments, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end
