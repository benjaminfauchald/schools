class CreateMagicLinkTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :magic_link_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.string :purpose, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at

      t.timestamps
    end
    
    add_index :magic_link_tokens, :token, unique: true
    add_index :magic_link_tokens, [:user_id, :purpose]
    add_index :magic_link_tokens, :expires_at
  end
end
