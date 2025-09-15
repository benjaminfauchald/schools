class MakeMediaItemUrlNullable < ActiveRecord::Migration[8.0]
  def change
    # Allow URL to be null for media items that use ActiveStorage file attachments
    change_column_null :media_items, :url, true
  end
end