class CreateVocabularies < ActiveRecord::Migration[8.0]
  def change
    create_table :vocabularies do |t|
      t.string :code, null: false
      t.string :label, null: false
      t.text :description

      t.timestamps
    end

    add_index :vocabularies, :code, unique: true
  end
end
