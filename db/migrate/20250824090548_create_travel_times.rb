class CreateTravelTimes < ActiveRecord::Migration[8.0]
  def change
    create_table :travel_times do |t|
      t.references :place, null: false, foreign_key: true
      t.string :origin_hash, null: false
      t.string :mode, null: false, default: 'driving'
      t.integer :minutes
      t.datetime :computed_at, null: false

      t.timestamps
    end

    add_index :travel_times, [ :place_id, :origin_hash, :mode ], unique: true
    add_index :travel_times, :computed_at
  end
end
