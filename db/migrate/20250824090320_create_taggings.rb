class CreateTaggings < ActiveRecord::Migration[8.0]
  def change
    create_table :taggings do |t|
      t.references :term, null: false, foreign_key: true
      t.string :taggable_type, null: false
      t.bigint :taggable_id, null: false
      t.string :context, null: false
      t.text :notes
      t.date :valid_from
      t.date :valid_to
      
      t.timestamps
    end
    
    # Polymorphic index
    add_index :taggings, [:taggable_type, :taggable_id]
    
    # Other useful indexes (check existence)
    add_index :taggings, :term_id unless index_exists?(:taggings, :term_id)
    add_index :taggings, :context
    add_index :taggings, [:taggable_type, :taggable_id, :context], name: 'index_taggings_on_taggable_and_context'
    
    # Unique constraint: one term per context per taggable (prevents duplicates)
    add_index :taggings, [:term_id, :taggable_type, :taggable_id, :context], 
              unique: true, name: 'index_taggings_unique_term_per_context'
    
    # Index for validity date queries
    add_index :taggings, [:valid_from, :valid_to]
  end
end
