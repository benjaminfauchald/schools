class AddCleanedTranscriptToTranscripts < ActiveRecord::Migration[8.0]
  def change
    add_column :transcripts, :cleaned_transcript, :text
    add_column :transcripts, :transcript_cleaned_at, :datetime
    
    # Add index for finding transcripts that need cleaning
    add_index :transcripts, :transcript_cleaned_at
    
    # Add index for finding transcripts with cleaned content
    add_index :transcripts, [:cleaned_transcript], where: "cleaned_transcript IS NOT NULL", 
              name: "index_transcripts_on_cleaned_transcript_present"
  end
end
