class CreateAiMessages < ActiveRecord::Migration[8.0]
  def up
    create_table :ai_messages do |t|
      t.references :ai_conversation, null: false, foreign_key: true, index: false
      t.string :role, null: false # 'user' or 'assistant'
      t.text :content, null: false
      t.json :source_references # which documents/transcripts/data were used
      t.json :metadata
      t.string :message_type, default: 'text' # 'text', 'suggested_question', 'data_analysis'

      t.timestamps
    end
    
    # Add indexes separately after table creation
    add_index :ai_messages, :ai_conversation_id
    add_index :ai_messages, :role
    add_index :ai_messages, :message_type
    add_index :ai_messages, :created_at
  end
  
  def down
    drop_table :ai_messages
  end
end
