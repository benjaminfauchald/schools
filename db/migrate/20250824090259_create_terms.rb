class CreateTerms < ActiveRecord::Migration[8.0]
  def change
    create_table :terms do |t|
      t.references :vocabulary, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :label, null: false
      t.text :description
      t.jsonb :metadata, default: {}
      t.references :parent, null: true, foreign_key: { to_table: :terms }
      t.boolean :is_active, default: true
      
      t.timestamps
    end
    
    # Unique slug per vocabulary
    add_index :terms, [:vocabulary_id, :slug], unique: true
    
    # Trigram indexes for fuzzy search
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')
    add_index :terms, :slug, using: :gin, opclass: :gin_trgm_ops
    add_index :terms, :label, using: :gin, opclass: :gin_trgm_ops
    
    # Regular indexes (check existence first)
    add_index :terms, :vocabulary_id unless index_exists?(:terms, :vocabulary_id)
    add_index :terms, :parent_id unless index_exists?(:terms, :parent_id)
    add_index :terms, :is_active unless index_exists?(:terms, :is_active)
    
    # GIN index for JSONB metadata queries
    add_index :terms, :metadata, using: :gin
  end
end
