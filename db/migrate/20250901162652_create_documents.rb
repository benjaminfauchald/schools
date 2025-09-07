class CreateDocuments < ActiveRecord::Migration[8.0]
  def up
    # Enable pgvector extension if not already enabled
    execute "CREATE EXTENSION IF NOT EXISTS vector;"

    # Only create the table if it doesn't exist (for development compatibility)
    unless table_exists?(:documents)
      create_table :documents do |t|
        # Core associations and metadata
        t.references :place, null: false, foreign_key: true
        t.string :filename, null: false
        t.string :original_filename
        t.string :content_type
        t.integer :file_size

        # Extracted content and metadata
        t.text :extracted_text
        t.json :metadata

        # File integrity and duplicate prevention
        t.string :file_checksum, null: false

        # Processing status tracking
        t.boolean :processing_completed, default: false
        t.boolean :processing_failed, default: false
        t.text :processing_error
        t.datetime :last_processed_at

        # AI and user management
        t.boolean :ai_enabled, default: true
        t.integer :download_count, default: 0

        t.timestamps
      end

      # Add vector column using raw SQL (PostGIS adapter compatibility)
      execute "ALTER TABLE documents ADD COLUMN embedding vector(1536);"

      # Add indexes for performance and constraints
      add_index :documents, :place_id unless index_exists?(:documents, :place_id)
      add_index :documents, [ :file_checksum, :place_id ], unique: true, name: 'index_documents_on_checksum_and_place' unless index_exists?(:documents, [ :file_checksum, :place_id ])
      add_index :documents, :processing_completed unless index_exists?(:documents, :processing_completed)
      add_index :documents, :ai_enabled unless index_exists?(:documents, :ai_enabled)
      add_index :documents, :created_at unless index_exists?(:documents, :created_at)

      # HNSW index for vector similarity search
      execute "CREATE INDEX IF NOT EXISTS index_documents_on_embedding_hnsw ON documents USING hnsw (embedding vector_cosine_ops);"
    end
  end

  def down
    drop_table :documents if table_exists?(:documents)
    # Note: Extension is left enabled for other potential vector tables
  end
end
