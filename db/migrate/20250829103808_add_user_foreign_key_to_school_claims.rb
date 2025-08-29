class AddUserForeignKeyToSchoolClaims < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :school_claims, :users, column: :user_id
    add_index :school_claims, :user_id unless index_exists?(:school_claims, :user_id)
  end
end
