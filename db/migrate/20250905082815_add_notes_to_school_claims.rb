class AddNotesToSchoolClaims < ActiveRecord::Migration[8.0]
  def change
    add_column :school_claims, :notes, :text
  end
end
