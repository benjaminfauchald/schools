class AddMissingFieldsToTranscriptSegments < ActiveRecord::Migration[8.0]
  def change
    add_column :transcript_segments, :confidence, :float
    add_column :transcript_segments, :raw_segment_data, :json
  end
end
