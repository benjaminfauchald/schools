class CreatePages < ActiveRecord::Migration[8.0]
  def change
    create_table :pages do |t|
      t.belongs_to :school, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false
      t.text :content, null: false
      t.string :page_type, default: 'blog', null: false
      t.string :status, default: 'draft', null: false
      t.string :author
      t.datetime :published_at
      t.text :meta_description
      t.string :featured_image_url
      t.integer :sort_order, default: 0

      t.timestamps
    end

    # Indexes for performance
    add_index :pages, [ :school_id, :slug ], unique: true
    add_index :pages, [ :school_id, :status ]
    add_index :pages, [ :school_id, :page_type ]
    add_index :pages, :published_at
    add_index :pages, [ :status, :published_at ]
    add_index :pages, :sort_order
  end
end
