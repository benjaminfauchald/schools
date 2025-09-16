class RemoveAdminUsersTableFinal < ActiveRecord::Migration[8.0]
  def up
    drop_table :admin_users if table_exists?(:admin_users)
  end

  def down
    # Recreate the table structure if needed to rollback
    unless table_exists?(:admin_users)
      create_table :admin_users do |t|
        t.string :email, null: false, default: ""
        t.string :encrypted_password, null: false, default: ""
        t.string :reset_password_token
        t.datetime :reset_password_sent_at
        t.datetime :remember_created_at
        t.timestamps null: false
      end

      add_index :admin_users, :email, unique: true
      add_index :admin_users, :reset_password_token, unique: true
    end
  end
end
