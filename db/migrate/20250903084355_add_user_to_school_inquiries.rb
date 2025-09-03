class AddUserToSchoolInquiries < ActiveRecord::Migration[8.0]
  def change
    add_reference :school_inquiries, :user, null: true, foreign_key: true
  end
end
