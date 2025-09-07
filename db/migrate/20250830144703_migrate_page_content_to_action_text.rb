class MigratePageContentToActionText < ActiveRecord::Migration[8.0]
  def up
    say "Starting migration of page content to ActionText..."

    # Temporarily disable has_rich_text to access the content column directly
    Page.reset_column_information

    migrated_count = 0
    Page.find_each do |page|
      # Read content directly from the database column
      old_content = Page.connection.select_value("SELECT content FROM pages WHERE id = #{page.id}")

      if old_content.present?
        # Create ActionText rich text record
        page.content = old_content
        page.save!(validate: false) # Skip validations during migration

        migrated_count += 1
        say "Migrated page ID: #{page.id} (#{page.title.truncate(50)})" if migrated_count % 100 == 0
      end
    end

    say "Migrated #{migrated_count} pages to ActionText"

    # Remove the old content column after migration
    if column_exists?(:pages, :content)
      remove_column :pages, :content
      say "Removed old content column"
    end

    say "Migration complete!"
  end

  def down
    say "Rolling back ActionText migration..."

    # Re-add the content column
    unless column_exists?(:pages, :content)
      add_column :pages, :content, :text, null: false, default: ''
    end

    # Reset column information
    Page.reset_column_information

    restored_count = 0
    Page.find_each do |page|
      if page.content.present?
        content_html = page.content.body.to_s
        Page.where(id: page.id).update_all(content: content_html)

        restored_count += 1
        say "Restored page ID: #{page.id}" if restored_count % 100 == 0
      end
    end

    say "Restored #{restored_count} pages to content column"
    say "Rollback complete!"
  end
end
