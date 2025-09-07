class CreateSchoolFeeBands < ActiveRecord::Migration[8.0]
  def change
    create_table :school_fee_bands do |t|
      t.references :school_fee_schedule, null: false, foreign_key: true
      t.integer :grade_from, null: false
      t.integer :grade_to, null: false
      t.decimal :annual_tuition, precision: 10, scale: 2, null: false

      t.timestamps
    end

    add_index :school_fee_bands, [ :school_fee_schedule_id, :grade_from, :grade_to ],
              name: 'index_school_fee_bands_on_schedule_and_grades', unique: true
  end
end
