class AddWebCrawlingFieldsToPlaces < ActiveRecord::Migration[8.0]
  def change
    # Add columns only if they don't exist
    add_column :places, :website_crawled_at, :datetime unless column_exists?(:places, :website_crawled_at)
    add_column :places, :website_crawling_status, :string unless column_exists?(:places, :website_crawling_status)
    add_column :places, :website_crawl_job_id, :string unless column_exists?(:places, :website_crawl_job_id)
    add_column :places, :website_pages_found, :integer unless column_exists?(:places, :website_pages_found)
    add_column :places, :website_crawl_data, :json unless column_exists?(:places, :website_crawl_data)
    add_column :places, :website_structured_data, :json unless column_exists?(:places, :website_structured_data)
    add_column :places, :website_crawling_error, :text unless column_exists?(:places, :website_crawling_error)

    # Add indexes for performance (check existence)
    add_index :places, :website_crawling_status unless index_exists?(:places, :website_crawling_status)
    add_index :places, :website_crawled_at unless index_exists?(:places, :website_crawled_at)
  end
end
