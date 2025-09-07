class CreateTempClaims < ActiveRecord::Migration[8.0]
  def change
    create_table :temp_claims do |t|
      t.references :school, null: false, foreign_key: true
      t.string :token, null: false
      t.string :email, null: false
      t.string :evidence_url
      t.text :notes
      t.string :ip_address
      t.datetime :expires_at, null: false
      t.string :status, default: 'pending_registration'

      t.timestamps
    end

    add_index :temp_claims, :token, unique: true
    add_index :temp_claims, :email
    add_index :temp_claims, :status
    add_index :temp_claims, :expires_at
  end
end
