require 'open3'

class ImportSchoolWebsiteDataJob < ApplicationJob
  queue_as :default
  
  # Retry up to 2 times with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 2
  
  def perform(school_id)
    school = School.find(school_id)
    
    Rails.logger.info "Starting website import for school #{school.id} (#{school.name})"
    
    # Update status to indicate crawling started
    school.update!(
      website_crawling_status: 'crawling',
      website_crawling_error: nil
    )
    
    # Use the existing firecrawl rake task logic
    website_url = school.website_url.present? ? school.website_url : school.place&.website
    
    unless website_url.present?
      error_msg = "No website URL found for school #{school.id}"
      Rails.logger.error error_msg
      school.update!(
        website_crawling_status: 'failed',
        website_crawling_error: error_msg
      )
      return
    end
    
    # Validate URL format
    unless website_url.match?(URI::DEFAULT_PARSER.make_regexp(['http', 'https']))
      error_msg = "Invalid website URL format: #{website_url}"
      Rails.logger.error error_msg
      school.update!(
        website_crawling_status: 'failed',
        website_crawling_error: error_msg
      )
      return
    end
    
    begin
      # Use the Python script for firecrawl integration
      python_script = Rails.root.join('scripts', 'crawl_school_websites.py').to_s
      
      unless File.exist?(python_script)
        error_msg = "Python crawling script not found at: #{python_script}"
        Rails.logger.error error_msg
        school.update!(
          website_crawling_status: 'failed',
          website_crawling_error: error_msg
        )
        return
      end
      
      # Execute Python script
      cmd = "python3 #{python_script} --website \"#{website_url}\""
      stdout, stderr, status = Open3.capture3(cmd)
      
      if status.success?
        # Parse results
        crawl_result = JSON.parse(stdout)
        
        if crawl_result['success']
          # Update school with successful crawl results
          school.update!(
            website_crawled_at: Time.current,
            website_crawling_status: 'completed',
            website_pages_found: crawl_result['pages_found'],
            website_crawl_data: crawl_result['raw_data'],
            website_structured_data: crawl_result['structured_data'],
            website_crawling_error: nil
          )
          
          Rails.logger.info "Successfully crawled #{crawl_result['pages_found']} pages for school #{school.id}"
          
          # Create audit log entry with consistent field name
          AuditLog.create!(
            auditable: school,
            action: 'update',
            changed_fields: {
              'website_crawl_pages' => [nil, crawl_result['pages_found']],
              'website_crawl_completed' => [nil, Time.current.iso8601]
            }
          )
        else
          # Handle crawl failure
          error_msg = crawl_result['error'] || 'Unknown crawl error'
          Rails.logger.error "Crawl failed for school #{school.id}: #{error_msg}"
          
          school.update!(
            website_crawling_status: 'failed',
            website_crawling_error: error_msg
          )
        end
      else
        # Handle script execution failure
        error_msg = "Python script failed: #{stderr.truncate(200)}"
        Rails.logger.error "Script execution failed for school #{school.id}: #{error_msg}"
        
        school.update!(
          website_crawling_status: 'failed',
          website_crawling_error: error_msg
        )
      end
      
    rescue JSON::ParserError => e
      error_msg = "Failed to parse crawl results: #{e.message}"
      Rails.logger.error "JSON parse error for school #{school.id}: #{error_msg}"
      
      school.update!(
        website_crawling_status: 'failed',
        website_crawling_error: error_msg
      )
    rescue => e
      error_msg = "Unexpected error during website import: #{e.message}"
      Rails.logger.error "Unexpected error for school #{school.id}: #{error_msg}"
      Rails.logger.error e.backtrace.join("\n")
      
      school.update!(
        website_crawling_status: 'failed',
        website_crawling_error: error_msg
      )
      
      # Re-raise to trigger retry mechanism
      raise e
    end
  end
end