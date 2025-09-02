class UpdateTranscriptStatus < ActiveRecord::Migration[8.0]
  def up
    # Add the new 'no_transcript' status to the enum
    # This is safe since it doesn't change existing values
    execute <<-SQL
      -- The enum already allows string values, so no need to modify the enum type
      -- We just need to update any existing records that should be 'no_transcript'
      UPDATE transcripts 
      SET status = 'no_transcript' 
      WHERE status = 'failed' 
      AND (
        processing_error ILIKE '%no captions%' OR
        processing_error ILIKE '%video not found%' OR
        processing_error ILIKE '%no speech%' OR
        processing_error ILIKE '%video too short%' OR
        processing_error ILIKE '%no audio%'
      );
    SQL
  end

  def down
    # Convert 'no_transcript' back to 'failed' if rolling back
    execute <<-SQL
      UPDATE transcripts 
      SET status = 'failed' 
      WHERE status = 'no_transcript';
    SQL
  end
end
