class RemoveCleanedTranscriptIndex < ActiveRecord::Migration[8.0]
  def change
    # Remove the problematic index on cleaned_transcript full text column
    # This index causes "index row size exceeds btree maximum" errors for large transcripts
    remove_index :transcripts, name: 'index_transcripts_on_cleaned_transcript_present', if_exists: true

    # We don't need to index the full cleaned_transcript text content
    # Queries can use the transcript_cleaned_at timestamp for filtering cleaned transcripts
  end
end
