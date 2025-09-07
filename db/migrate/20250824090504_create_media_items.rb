class CreateMediaItems < ActiveRecord::Migration[8.0]
  def change
    create_table :media_items do |t|
      t.references :place, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :url, null: false
      t.string :alt_text
      t.integer :sort_order, default: 0

      t.timestamps
    end

    add_index :media_items, [ :place_id, :kind ]
    add_index :media_items, [ :place_id, :sort_order ]
  end
end
