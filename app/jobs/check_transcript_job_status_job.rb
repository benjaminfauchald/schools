# Job to check status of async Supadata transcript processing jobs
class CheckTranscriptJobStatusJob < ApplicationJob
  queue_as :default
  
  def perform(transcript_id, supadata_job_id, attempt = 1)
    transcript = Transcript.find_by(id: transcript_id)
    return unless transcript
    
    Rails.logger.info "🔍 Checking Supadata job status: #{supadata_job_id} (attempt #{attempt})"
    
    service = SupadataService.new
    status_result = service.get_job_status(supadata_job_id)
    
    if status_result[:success]
      case status_result[:status]
      when 'completed'
        Rails.logger.info "✅ Supadata job completed: #{supadata_job_id}"
        # Process the transcript data
        transcript_result = service.get_transcript(transcript.video_url)
        if transcript_result[:success]
          ProcessVideoTranscriptJob.new.process_transcript_data(transcript, transcript_result[:data])
        else
          Rails.logger.error "❌ Failed to retrieve completed transcript: #{transcript_result[:error]}"
          transcript.mark_failed!(transcript_result[:error])
        end
        
      when 'processing'
        Rails.logger.info "⏳ Supadata job still processing: #{supadata_job_id}"
        # Schedule next check if we haven't exceeded max attempts
        if attempt < 20 # Max ~30 minutes of checking
          CheckTranscriptJobStatusJob.set(wait: 90.seconds).perform_later(transcript_id, supadata_job_id, attempt + 1)
        else
          Rails.logger.error "⏰ Supadata job timeout: #{supadata_job_id}"
          transcript.mark_failed!('Processing timeout after 30 minutes')
        end
        
      when 'failed', 'error'
        Rails.logger.error "❌ Supadata job failed: #{supadata_job_id} - #{status_result[:error]}"
        error_msg = status_result[:error] || 'Supadata processing failed'
        
        # Check if this is a "no transcript" case based on error message
        if error_msg.match?(/no captions|no speech|video too short|no audio|video not found/i)
          transcript.mark_no_transcript!(error_msg)
          Rails.logger.info "📝 Marked as no transcript: #{supadata_job_id} - #{error_msg}"
        else
          transcript.mark_failed!(error_msg)
        end
        
      when 'no_transcript', 'no_captions', 'no_speech'
        Rails.logger.info "📝 Supadata job completed with no transcript: #{supadata_job_id}"
        transcript.mark_no_transcript!(status_result[:message] || 'No speech content available')
        
      else
        Rails.logger.warn "❓ Unknown Supadata job status: #{status_result[:status]}"
        # Schedule retry for unknown status
        if attempt < 5
          CheckTranscriptJobStatusJob.set(wait: 60.seconds).perform_later(transcript_id, supadata_job_id, attempt + 1)
        else
          transcript.mark_failed!("Unknown status after #{attempt} attempts: #{status_result[:status]}")
        end
      end
    else
      Rails.logger.error "❌ Failed to check Supadata job status: #{status_result[:error]}"
      # Retry on API errors
      if attempt < 10
        CheckTranscriptJobStatusJob.set(wait: 120.seconds).perform_later(transcript_id, supadata_job_id, attempt + 1)
      else
        transcript.mark_failed!("Failed to check job status after #{attempt} attempts: #{status_result[:error]}")
      end
    end
    
  rescue => e
    Rails.logger.error "💥 CheckTranscriptJobStatusJob error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Retry on unexpected errors
    if attempt < 5
      CheckTranscriptJobStatusJob.set(wait: 300.seconds).perform_later(transcript_id, supadata_job_id, attempt + 1)
    else
      transcript&.mark_failed!("Unexpected error after #{attempt} attempts: #{e.message}")
    end
  end
end