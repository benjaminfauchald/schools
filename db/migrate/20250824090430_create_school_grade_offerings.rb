class CreateSchoolGradeOfferings < ActiveRecord::Migration[8.0]
  def change
    create_table :school_grade_offerings do |t|
      t.references :school, null: false, foreign_key: true, index: { unique: true }
      t.decimal :min_age, precision: 3, scale: 1
      t.decimal :max_age, precision: 3, scale: 1
      t.string :grades
      t.text :notes

      t.timestamps
    end

    add_index :school_grade_offerings, [ :min_age, :max_age ]
  end
end
