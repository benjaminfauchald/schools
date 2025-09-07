class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs do |t|
      t.string :auditable_type, null: false
      t.bigint :auditable_id, null: false
      t.bigint :user_id
      t.string :action, null: false
      t.jsonb :changed_fields, default: {}

      t.timestamps
    end

    add_index :audit_logs, [ :auditable_type, :auditable_id ]
    add_index :audit_logs, :user_id
    add_index :audit_logs, :action
    add_index :audit_logs, :created_at
    add_index :audit_logs, :changed_fields, using: :gin
  end
end
