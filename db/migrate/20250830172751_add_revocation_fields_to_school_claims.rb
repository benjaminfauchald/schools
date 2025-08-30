class AddRevocationFieldsToSchoolClaims < ActiveRecord::Migration[8.0]
  def change
    add_column :school_claims, :revoked_at, :datetime
    add_column :school_claims, :revoked_by_id, :bigint
    add_column :school_claims, :revocation_reason, :text
    
    add_index :school_claims, :revoked_at
    add_index :school_claims, :revoked_by_id
  end
end
