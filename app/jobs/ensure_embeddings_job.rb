# On-demand job for ensuring transcript embeddings are available
# Triggered when user needs embeddings for AI chat or search functionality
class EnsureEmbeddingsJob < ApplicationJob
  queue_as :high_priority
  
  # No retries for on-demand jobs - fail fast for better user experience
  retry_on StandardError, wait: 5.seconds, attempts: 2
  
  # Discard job on configuration errors
  discard_on ArgumentError
  
  def perform(transcript_id, options = {})
    callback_method = options['callback_method']
    callback_params = options['callback_params'] || {}
    
    Rails.logger.info "🏃‍♂️ EnsureEmbeddingsJob started for transcript #{transcript_id}"
    
    begin
      transcript = Transcript.find(transcript_id)
      Rails.logger.info "📹 Processing transcript: #{transcript.video_title || transcript.video_id}"
      
      # Check if embedding already exists and is recent
      if embedding_exists_and_valid?(transcript)
        Rails.logger.info "✅ Embedding already exists for transcript #{transcript_id}"
        
        # Execute callback if provided
        execute_callback(callback_method, callback_params.merge(transcript_id: transcript_id, status: 'existing'))
        return { success: true, action: 'existing', transcript_id: transcript_id }
      end
      
      # Generate embeddings
      embedding_service = EmbeddingGenerationService.new
      result = embedding_service.process_transcript(transcript)
      
      if result[:success]
        Rails.logger.info "✅ Successfully generated embeddings for transcript #{transcript_id}"
        Rails.logger.info "📊 Processed #{result[:segments_processed]} segments"
        
        # Execute callback if provided
        execute_callback(callback_method, callback_params.merge(transcript_id: transcript_id, status: 'generated', result: result))
        
        { success: true, action: 'generated', transcript_id: transcript_id, result: result }
      else
        Rails.logger.error "❌ Failed to generate embeddings for transcript #{transcript_id}: #{result[:error]}"
        
        # Execute error callback if provided
        execute_callback(callback_method, callback_params.merge(transcript_id: transcript_id, status: 'failed', error: result[:error]))
        
        { success: false, action: 'failed', transcript_id: transcript_id, error: result[:error] }
      end
      
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "❌ Transcript #{transcript_id} not found: #{e.message}"
      
      # Execute error callback
      execute_callback(callback_method, callback_params.merge(transcript_id: transcript_id, status: 'not_found', error: e.message))
      
      { success: false, action: 'not_found', transcript_id: transcript_id, error: e.message }
      
    rescue => e
      Rails.logger.error "💥 EnsureEmbeddingsJob failed for transcript #{transcript_id}: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      
      # Execute error callback
      execute_callback(callback_method, callback_params.merge(transcript_id: transcript_id, status: 'error', error: e.message))
      
      # Re-raise to trigger retry logic
      raise e
    end
  end
  
  # Ensure embeddings for multiple transcripts (e.g., for a school's videos)
  def self.perform_for_school(school_id, options = {})
    school = School.find(school_id)
    place = school.place
    
    return unless place&.transcripts&.any?
    
    Rails.logger.info "🏫 Enqueueing embedding jobs for school #{school.name}"
    
    # Find transcripts that might need embeddings
    transcripts_to_check = place.transcripts.processed.ai_enabled
                                .where(vector_embedding: nil)
                                .or(place.transcripts.processed.ai_enabled.where(embedding_generated_at: nil))
    
    job_count = 0
    transcripts_to_check.find_each do |transcript|
      EnsureEmbeddingsJob.perform_later(
        transcript.id,
        options.merge(
          school_id: school_id,
          callback_method: 'broadcast_school_embedding_status'
        )
      )
      job_count += 1
    end
    
    Rails.logger.info "📤 Enqueued #{job_count} embedding jobs for school #{school.name}"
    job_count
  end
  
  private
  
  def embedding_exists_and_valid?(transcript)
    # Check if transcript has vector embedding
    return false unless transcript.vector_embedding.present?
    
    # Check if embedding was generated recently (optional freshness check)
    if transcript.embedding_generated_at.present?
      # Consider embeddings valid if generated within the last 30 days
      # This allows for re-generation if the embedding model is updated
      freshness_threshold = 30.days.ago
      return transcript.embedding_generated_at > freshness_threshold
    end
    
    # If no generation timestamp, assume it's valid if it exists and has correct format
    true
  end
  
  def execute_callback(callback_method, params)
    return unless callback_method.present?
    
    case callback_method
    when 'broadcast_school_embedding_status'
      broadcast_school_embedding_status(params)
    when 'broadcast_transcript_ready'
      broadcast_transcript_ready(params)
    else
      Rails.logger.warn "⚠️ Unknown callback method: #{callback_method}"
    end
  end
  
  def broadcast_school_embedding_status(params)
    school_id = params[:school_id]
    transcript_id = params[:transcript_id]
    status = params[:status]
    
    return unless school_id
    
    Rails.logger.debug "📡 Broadcasting embedding status for school #{school_id}, transcript #{transcript_id}: #{status}"
    
    # Update school embedding status in real-time
    Turbo::StreamsChannel.broadcast_replace_to(
      "school_#{school_id}_transcripts",
      target: "transcript_#{transcript_id}_status",
      html: ApplicationController.render(
        partial: 'school_owner/transcripts/embedding_status',
        locals: {
          transcript_id: transcript_id,
          status: status,
          timestamp: Time.current
        }
      )
    )
  rescue => e
    Rails.logger.warn "⚠️ Failed to broadcast school embedding status: #{e.message}"
  end
  
  def broadcast_transcript_ready(params)
    transcript_id = params[:transcript_id]
    status = params[:status]
    
    Rails.logger.debug "📡 Broadcasting transcript ready status for transcript #{transcript_id}: #{status}"
    
    # Broadcast that transcript is ready for AI processing
    Turbo::StreamsChannel.broadcast_replace_to(
      "transcript_#{transcript_id}",
      target: "transcript_#{transcript_id}_ai_status",
      html: ApplicationController.render(
        partial: 'shared/transcript_ai_status',
        locals: {
          transcript_id: transcript_id,
          status: status,
          ready_for_ai: (status == 'generated' || status == 'existing')
        }
      )
    )
  rescue => e
    Rails.logger.warn "⚠️ Failed to broadcast transcript ready status: #{e.message}"
  end
end