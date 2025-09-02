# Background job to process YouTube video transcripts using Supadata API
# Handles both sync and async transcript processing workflows
class ProcessVideoTranscriptJob < ApplicationJob
  queue_as :default
  
  # Retry failed jobs with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  # Don't retry certain permanent errors
  discard_on StandardError do |job, error|
    # Check if the error is from a permanent failure
    if job.arguments.last.is_a?(Hash) && job.arguments.last[:permanent_error]
      Rails.logger.info "🚮 Discarding job #{job.job_id} due to permanent error: #{error.message}"
      true
    else
      false
    end
  end
  
  def perform(youtube_video_id, place_id, options = {})
    Rails.logger.info "🎬 ProcessVideoTranscriptJob started for video #{youtube_video_id}"
    
    @youtube_video = YoutubeVideo.find_by(id: youtube_video_id)
    @place = Place.find_by(id: place_id)
    
    unless @youtube_video && @place
      Rails.logger.error "❌ Video or place not found: video=#{youtube_video_id}, place=#{place_id}"
      return
    end
    
    Rails.logger.info "🎯 Processing transcript for: #{@youtube_video.title} (#{@youtube_video.video_id})"
    
    # Find or create transcript record
    @transcript = find_or_create_transcript
    
    # Skip if already completed unless forced
    if @transcript.completed? && !options[:force]
      Rails.logger.info "✅ Transcript already completed for #{@youtube_video.video_id}"
      return
    end
    
    # Mark as processing
    @transcript.mark_processing!
    
    # Process the transcript
    process_transcript(options)
    
  rescue => e
    Rails.logger.error "🚨 ProcessVideoTranscriptJob failed for video #{youtube_video_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    if @transcript
      @transcript.mark_failed!(e.message)
    end
    
    raise e
  end
  
  private
  
  def find_or_create_transcript
    @place.transcripts.find_or_create_by(video_id: @youtube_video.video_id) do |transcript|
      transcript.video_title = @youtube_video.title
      transcript.video_description = @youtube_video.description
      transcript.video_url = @youtube_video.youtube_url
      transcript.status = 'pending'
    end
  end
  
  def process_transcript(options = {})
    supadata = SupadataService.new
    
    Rails.logger.info "📡 Calling Supadata API for video #{@youtube_video.video_id}"
    result = supadata.get_transcript(@youtube_video.youtube_url, options)
    
    if result[:success]
      if result[:async]
        # Async processing - schedule job to check status
        handle_async_processing(result[:job_id])
      else
        # Direct result - process immediately
        handle_sync_result(result)
      end
    else
      handle_api_error(result)
    end
  end
  
  def handle_sync_result(result)
    Rails.logger.info "✅ Got direct transcript result for #{@youtube_video.video_id}"
    
    transcript_text = extract_full_text(result[:segments])
    segments_data = result[:segments]
    
    if transcript_text.present?
      # Mark transcript as completed and create segments
      @transcript.mark_completed!(transcript_text, segments_data)
      
      Rails.logger.info "🎉 Transcript completed for #{@youtube_video.video_id}: #{segments_data.count} segments"
    else
      @transcript.mark_no_transcript!("No speech content detected in video")
      Rails.logger.warn "📝 No transcript content for #{@youtube_video.video_id}"
    end
  end
  
  def handle_async_processing(job_id)
    Rails.logger.info "⏳ Transcript processing started async with job #{job_id} for #{@youtube_video.video_id}"
    
    # Store job ID in transcript for tracking
    @transcript.update!(
      processing_job_id: job_id,
      status: 'processing'
    )
    
    # Schedule a job to check status in 30 seconds
    CheckTranscriptJobStatusJob.set(wait: 30.seconds).perform_later(
      @transcript.id,
      job_id
    )
  end
  
  def handle_api_error(result)
    error_message = result[:error]
    is_permanent = result[:permanent]
    
    Rails.logger.error "❌ Supadata API error for #{@youtube_video.video_id}: #{error_message}"
    
    case error_message
    when "video_not_found"
      @transcript.mark_no_transcript!("Video not found or unavailable")
      Rails.logger.info "📹 Video not found: #{@youtube_video.video_id}"
      
    when "no_captions_available", "no_speech_detected", "video_too_short", "no_audio_track"
      @transcript.mark_no_transcript!("No captions or speech available for this video")
      Rails.logger.info "📝 No transcript content available: #{@youtube_video.video_id} - #{error_message}"
      
    when "rate_limit_exceeded"
      retry_after = result[:retry_after] || 300 # Longer wait for rate limits
      # Add random jitter to prevent thundering herd
      jitter = rand(60..180)
      wait_time = retry_after + jitter
      
      Rails.logger.warn "⏱️ Rate limit exceeded, retrying in #{wait_time} seconds (#{retry_after}+#{jitter} jitter)"
      
      # Reschedule the job with jitter
      ProcessVideoTranscriptJob.set(wait: wait_time.seconds).perform_later(
        @youtube_video.id,
        @place.id,
        options.merge(retry_attempt: (options[:retry_attempt] || 0) + 1)
      )
      
    when "unauthorized"
      @transcript.mark_failed!("API authentication failed")
      Rails.logger.error "🔑 Supadata API unauthorized - check API key"
      
    else
      if is_permanent
        @transcript.mark_failed!(error_message)
      else
        # Temporary error - let the job retry
        raise StandardError.new("Supadata API error: #{error_message}")
      end
    end
    
    # Mark as permanent error to avoid retries for certain cases
    if is_permanent
      error = StandardError.new("Permanent error: #{error_message}")
      # Store permanent error flag in the error object
      error.define_singleton_method(:permanent_error?) { true }
      raise error
    end
  end
  
  def extract_full_text(segments)
    return "" unless segments.is_a?(Array)
    
    segments.map { |seg| seg[:text] }.compact.join(" ")
  end
end

