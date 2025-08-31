class YoutubeTranscriptExtractionJob < ApplicationJob
  queue_as :default
  
  # Retry configuration for API failures
  retry_on Net::TimeoutError, wait: :polynomially_longer, attempts: 3
  retry_on StandardError, wait: 30.seconds, attempts: 2
  
  def perform(place_id, video_data_or_list, options = {})
    place = Place.find(place_id)
    service = YoutubeTranscriptService.new
    
    Rails.logger.info "Starting YouTube transcript extraction for place: #{place.name} (ID: #{place.id})"
    
    begin
      if video_data_or_list.is_a?(Array)
        # Process multiple videos
        result = service.extract_transcripts_for_place(place, video_data_or_list, options)
        
        Rails.logger.info "Batch transcript extraction completed for #{place.name}:"
        Rails.logger.info "  Total: #{result[:total_videos]}, Processed: #{result[:processed]}"
        Rails.logger.info "  Created: #{result[:created]}, Updated: #{result[:updated]}, Skipped: #{result[:skipped]}"
        Rails.logger.info "  Errors: #{result[:errors].length}"
        
        # Log any errors
        result[:errors].each do |error|
          Rails.logger.error "  Video '#{error[:video]}': #{error[:error]}"
        end
        
        # Store results in a way that can be accessed later (optional)
        if options[:store_results]
          place.update!(
            youtube_processing_results: {
              last_batch_processed_at: Time.current,
              last_batch_results: result
            }
          )
        end
        
      else
        # Process single video
        result = service.extract_and_create_transcript(place, video_data_or_list, options)
        
        if result[:success]
          Rails.logger.info "Successfully processed transcript for video: #{result[:transcript].video_title}"
          Rails.logger.info "  Segments created: #{result[:segments_created]}"
        else
          Rails.logger.error "Failed to process transcript: #{result[:error]}"
          raise StandardError, result[:error]
        end
      end
      
    rescue => e
      Rails.logger.error "YouTube transcript extraction job failed for place #{place.name}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Re-raise to trigger retry logic
      raise e
    end
  end
end