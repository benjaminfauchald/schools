class CreateSchoolInquiries < ActiveRecord::Migration[8.0]
  def change
    create_table :school_inquiries do |t|
      t.references :school, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.text :message, null: false
      t.integer :children_count, null: false
      t.string :status, default: 'new', null: false
      t.datetime :read_at
      t.string :ip_address
      t.text :admin_notes

      t.timestamps
    end

    add_index :school_inquiries, :status
    add_index :school_inquiries, :email
    add_index :school_inquiries, [ :school_id, :created_at ]
  end
end
