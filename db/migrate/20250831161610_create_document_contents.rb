class CreateDocumentContents < ActiveRecord::Migration[8.0]
  def change
    create_table :document_contents do |t|
      t.references :place, null: false, foreign_key: true
      t.string :title, null: false
      t.string :content_type, null: false
      t.text :processed_text
      t.json :metadata
      t.string :processing_status, default: 'pending'
      t.vector :embedding, limit: 1536

      t.timestamps
    end
    
    add_index :document_contents, :content_type
    add_index :document_contents, :processing_status
    add_index :document_contents, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end
