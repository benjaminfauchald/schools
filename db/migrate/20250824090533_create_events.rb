class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.references :place, null: false, foreign_key: true
      t.string :title, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.string :location
      t.string :url
      t.text :description

      t.timestamps
    end

    add_index :events, [ :place_id, :starts_at ]
    add_index :events, :starts_at
  end
end
