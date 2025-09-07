class CreateWebhookAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :webhook_audit_logs do |t|
      t.string :webhook_type, null: false
      t.string :facebook_user_id, null: false
      t.references :user, null: true, foreign_key: true # nullable in case user is deleted
      t.jsonb :payload, null: false
      t.string :status, default: 'processed'
      t.text :error_message
      t.timestamp :processed_at, default: -> { 'CURRENT_TIMESTAMP' }

      t.timestamps
    end

    add_index :webhook_audit_logs, :facebook_user_id
    add_index :webhook_audit_logs, :webhook_type
    add_index :webhook_audit_logs, :processed_at
    add_index :webhook_audit_logs, [ :webhook_type, :facebook_user_id ], name: 'idx_webhook_audit_type_fb_user'
  end
end
