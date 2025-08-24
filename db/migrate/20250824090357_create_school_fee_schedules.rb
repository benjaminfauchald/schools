class CreateSchoolFeeSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :school_fee_schedules do |t|
      t.references :school, null: false, foreign_key: true
      t.string :academic_year, null: false
      t.string :currency, default: 'THB', null: false
      t.decimal :application_fee, precision: 10, scale: 2
      t.decimal :enrollment_fee, precision: 10, scale: 2
      t.decimal :capital_levy, precision: 10, scale: 2
      t.decimal :min_tuition, precision: 10, scale: 2
      t.decimal :max_tuition, precision: 10, scale: 2
      t.decimal :boarding_fee_annual, precision: 10, scale: 2
      t.decimal :transport_fee_annual, precision: 10, scale: 2
      t.text :notes
      t.boolean :is_published, default: false

      t.timestamps
    end
    
    add_index :school_fee_schedules, [:school_id, :academic_year], unique: true
    add_index :school_fee_schedules, :is_published
  end
end
