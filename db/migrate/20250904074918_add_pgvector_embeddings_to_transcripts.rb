class AddPgvectorEmbeddingsToTranscripts < ActiveRecord::Migration[8.0]
  def up
    # Ensure pgvector extension is enabled
    execute "CREATE EXTENSION IF NOT EXISTS vector;"

    # Add pgvector embedding columns to transcripts table
    add_column :transcripts, :vector_embedding, 'vector(1536)'
    add_column :transcripts, :embedding_generated_at, :datetime

    # Add pgvector embedding columns to transcript_segments table
    add_column :transcript_segments, :vector_embedding, 'vector(1536)'
    add_column :transcript_segments, :embedding_generated_at, :datetime

    # Add indexes for embedding columns
    add_index :transcripts, :embedding_generated_at
    add_index :transcript_segments, :embedding_generated_at

    # Create HNSW indexes for vector similarity search on transcripts
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS index_transcripts_on_vector_embedding_hnsw#{' '}
      ON transcripts USING hnsw (vector_embedding vector_cosine_ops);
    SQL

    # Create HNSW indexes for vector similarity search on transcript_segments
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS index_transcript_segments_on_vector_embedding_hnsw#{' '}
      ON transcript_segments USING hnsw (vector_embedding vector_cosine_ops);
    SQL
  end

  def down
    # Remove indexes first
    execute "DROP INDEX IF EXISTS index_transcripts_on_vector_embedding_hnsw;"
    execute "DROP INDEX IF EXISTS index_transcript_segments_on_vector_embedding_hnsw;"

    remove_index :transcripts, :embedding_generated_at if index_exists?(:transcripts, :embedding_generated_at)
    remove_index :transcript_segments, :embedding_generated_at if index_exists?(:transcript_segments, :embedding_generated_at)

    # Remove columns
    remove_column :transcripts, :vector_embedding if column_exists?(:transcripts, :vector_embedding)
    remove_column :transcripts, :embedding_generated_at if column_exists?(:transcripts, :embedding_generated_at)
    remove_column :transcript_segments, :vector_embedding if column_exists?(:transcript_segments, :vector_embedding)
    remove_column :transcript_segments, :embedding_generated_at if column_exists?(:transcript_segments, :embedding_generated_at)
  end
end
