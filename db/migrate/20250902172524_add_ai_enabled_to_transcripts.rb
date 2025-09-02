class AddAiEnabledToTranscripts < ActiveRecord::Migration[8.0]
  def change
    add_column :transcripts, :ai_enabled, :boolean, default: true, null: false
    add_index :transcripts, :ai_enabled
  end
end
