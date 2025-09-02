class AddIndexesToAiMessages < ActiveRecord::Migration[8.0]
  def change
    add_index :ai_messages, :ai_conversation_id
    add_index :ai_messages, :role
    add_index :ai_messages, :message_type
    add_index :ai_messages, :created_at
  end
end
