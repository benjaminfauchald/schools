class AddWebsiteCrawlFieldsToSchools < ActiveRecord::Migration[8.0]
  def change
    add_column :schools, :website_crawled_at, :datetime
    add_column :schools, :website_crawling_status, :string
    add_column :schools, :website_pages_found, :integer
    add_column :schools, :website_crawl_data, :json
    add_column :schools, :website_structured_data, :json
    add_column :schools, :website_crawling_error, :text
  end
end
