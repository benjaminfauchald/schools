class AddPreferencesToSchools < ActiveRecord::Migration[8.0]
  def change
    add_column :schools, :preferences, :jsonb, default: {}, null: false
    add_index :schools, :preferences, using: :gin
  end
end
