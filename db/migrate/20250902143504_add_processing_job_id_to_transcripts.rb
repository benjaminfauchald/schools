class AddProcessingJobIdToTranscripts < ActiveRecord::Migration[8.0]
  def change
    add_column :transcripts, :processing_job_id, :string
  end
end
