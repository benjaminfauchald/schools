class CreateSchoolClaims < ActiveRecord::Migration[8.0]
  def change
    create_table :school_claims do |t|
      t.references :school, null: false, foreign_key: true
      t.bigint :user_id, null: false
      t.string :status, null: false, default: 'pending'
      t.string :evidence_url
      t.text :admin_notes

      t.timestamps
    end

    add_index :school_claims, [ :school_id, :user_id ], unique: true
    add_index :school_claims, :status
    add_index :school_claims, :user_id
  end
end
