class CreateAiConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_conversations do |t|
      t.references :school, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.string :status, default: 'active'
      t.json :metadata
      t.datetime :last_message_at

      t.timestamps
      
      t.index [:school_id, :user_id]
      t.index :last_message_at
      t.index :status
    end
  end
end
