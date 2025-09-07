class DropAdminUsersTable < ActiveRecord::Migration[8.0]
  def change
    drop_table :admin_users, if_exists: true do |t|
      # This block is for rollback purposes
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.timestamps null: false
    end
  end
end
