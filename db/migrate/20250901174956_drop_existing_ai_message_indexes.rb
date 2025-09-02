class DropExistingAiMessageIndexes < ActiveRecord::Migration[8.0]
  def up
    # Drop any stale indexes from failed migrations
    execute "DROP INDEX IF EXISTS index_ai_messages_on_ai_conversation_id"
    execute "DROP INDEX IF EXISTS index_ai_messages_on_role"
    execute "DROP INDEX IF EXISTS index_ai_messages_on_message_type"
    execute "DROP INDEX IF EXISTS index_ai_messages_on_created_at"
  end
  
  def down
    # No-op since these are cleanup operations
  end
end
