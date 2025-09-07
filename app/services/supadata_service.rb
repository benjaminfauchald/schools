# Supadata API Service for transcript extraction
# Provides interface to Supadata.ai API for YouTube transcript processing
class SupadataService
  include HTTParty

  base_uri "https://api.supadata.ai/v1"

  def initialize(api_key = nil)
    @api_key = api_key || ENV["SUPADATA_API_KEY"]
    raise "Supadata API key not configured" if @api_key.blank?

    @headers = {
      "x-api-key" => @api_key,
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }
  end

  # Get transcript for a YouTube video
  # Returns either direct transcript data or job ID for async processing
  def get_transcript(video_url, options = {})
    video_id = extract_video_id(video_url)
    return { success: false, error: "Invalid YouTube URL" } unless video_id

    Rails.logger.info "🎯 SupadataService: Getting transcript for video #{video_id}"

    begin
      query_params = {
        url: normalize_youtube_url(video_id),
        lang: options[:lang] || "en",
        text: false # Get timestamped segments, not plain text
      }

      Rails.logger.info "📤 SupadataService API request: GET /transcript with #{query_params}"

      response = self.class.get("/transcript",
        headers: @headers,
        query: query_params,
        timeout: 30
      )

      # Log response without body content to avoid encoding issues
      Rails.logger.info "📥 SupadataService API response: #{response.code} - body length: #{response.body.length}"

      handle_api_response(response, video_id)

    rescue Timeout::Error => e
      Rails.logger.error "⏰ SupadataService timeout for video #{video_id}: #{e.message}"
      { success: false, error: "API request timeout", retry_after: 60 }
    rescue => e
      Rails.logger.error "🚨 SupadataService error for video #{video_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, error: e.message }
    end
  end

  # Check status of async transcript job
  def check_job_status(job_id)
    Rails.logger.info "🔍 SupadataService: Checking job status for #{job_id}"

    begin
      response = self.class.get("/jobs/#{job_id}/status",
        headers: @headers,
        timeout: 15
      )

      handle_job_response(response, job_id)

    rescue => e
      Rails.logger.error "🚨 SupadataService job status error for #{job_id}: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Get results of completed transcript job
  def get_job_results(job_id)
    Rails.logger.info "📊 SupadataService: Getting job results for #{job_id}"

    begin
      response = self.class.get("/jobs/#{job_id}/results",
        headers: @headers,
        timeout: 30
      )

      handle_job_response(response, job_id)

    rescue => e
      Rails.logger.error "🚨 SupadataService job results error for #{job_id}: #{e.message}"
      { success: false, error: e.message }
    end
  end

  private

  def extract_video_id(url)
    return url if url.match?(/^[a-zA-Z0-9_-]{11}$/) # Already a video ID

    patterns = [
      /(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([a-zA-Z0-9_-]{11})/,
      /^([a-zA-Z0-9_-]{11})$/
    ]

    patterns.each do |pattern|
      match = url.match(pattern)
      return match[1] if match
    end

    nil
  end

  def normalize_youtube_url(video_id_or_url)
    # If it's already a full URL, return as-is
    return video_id_or_url if video_id_or_url.include?("youtube.com") || video_id_or_url.include?("youtu.be")

    # If it's just a video ID, construct the URL
    "https://www.youtube.com/watch?v=#{video_id_or_url}"
  end

  def handle_api_response(response, video_id)
    case response.code
    when 200
      # Ensure proper encoding handling
      response_body = response.body
      response_body = response_body.force_encoding("UTF-8") if response_body.encoding.name == "ASCII-8BIT"
      response_body = response_body.scrub # Remove invalid UTF-8 sequences
      data = JSON.parse(response_body)

      if data["jobId"].present?
        # Async processing - return job ID
        {
          success: true,
          async: true,
          job_id: data["jobId"],
          video_id: video_id,
          message: "Transcript processing started"
        }
      elsif data["content"].is_a?(Array)
        if data["content"].empty?
          # Empty content means no captions available
          Rails.logger.info "📝 No captions available for #{video_id}"
          { success: false, error: "no_captions_available", permanent: true }
        else
          # Direct result - return transcript data
          {
            success: true,
            async: false,
            video_id: video_id,
            transcript_data: data,
            segments: parse_supadata_segments(data["content"])
          }
        end
      else
        Rails.logger.warn "🤔 Unexpected Supadata response format for #{video_id}: #{data}"
        { success: false, error: "Unexpected API response format" }
      end

    when 404
      Rails.logger.warn "❌ Video not found: #{video_id}"
      { success: false, error: "video_not_found", permanent: true }

    when 400
      error_data = JSON.parse(response.body) rescue {}
      error_message = error_data["error"] || error_data["message"] || "Bad request"
      Rails.logger.warn "❌ Bad request for #{video_id}: #{error_message}"

      # Check if it's a no-captions error
      if error_message.downcase.include?("caption") || error_message.downcase.include?("transcript")
        { success: false, error: "no_captions_available", permanent: true }
      else
        { success: false, error: error_message }
      end

    when 429
      Rails.logger.warn "⏳ Rate limit exceeded for #{video_id}"
      retry_after = response.headers["Retry-After"]&.to_i || 60
      { success: false, error: "rate_limit_exceeded", retry_after: retry_after }

    when 401
      Rails.logger.error "🔑 Unauthorized Supadata API request"
      { success: false, error: "unauthorized", permanent: true }

    else
      Rails.logger.error "🚨 Unexpected Supadata API response #{response.code} for #{video_id}: #{response.body}"
      { success: false, error: "api_error_#{response.code}" }
    end
  end

  def handle_job_response(response, job_id)
    return { success: false, error: "api_error_#{response.code}" } unless response.code == 200

    begin
      data = JSON.parse(response.body)

      case data["status"]
      when "completed"
        {
          success: true,
          status: "completed",
          job_id: job_id,
          transcript_data: data["result"],
          segments: parse_segments(data["result"])
        }
      when "failed"
        {
          success: false,
          status: "failed",
          job_id: job_id,
          error: data["error"] || "Job failed"
        }
      when "queued", "active"
        {
          success: true,
          status: data["status"],
          job_id: job_id,
          progress: data["progress"]
        }
      else
        Rails.logger.warn "🤔 Unknown job status for #{job_id}: #{data['status']}"
        { success: false, error: "unknown_job_status" }
      end

    rescue JSON::ParserError => e
      Rails.logger.error "📝 Failed to parse job response for #{job_id}: #{e.message}"
      { success: false, error: "invalid_response" }
    end
  end

  def parse_segments(transcript_data)
    return [] unless transcript_data.present?

    segments = transcript_data["segments"] || []
    return [] unless segments.is_a?(Array)

    segments.map.with_index do |segment, index|
      {
        segment_index: index,
        text: segment["text"]&.strip,
        start_time: segment["start"]&.to_f,
        end_time: segment["end"]&.to_f,
        speaker: segment["speaker"],
        confidence: segment["confidence"]&.to_f
      }
    end.select { |seg| seg[:text].present? }
  end

  def parse_supadata_segments(content)
    return [] unless content.is_a?(Array)

    content.map.with_index do |segment, index|
      # Convert Supadata format to our internal format
      # Supadata uses offset (ms) and duration (ms), we need start/end times in seconds
      start_time_seconds = (segment["offset"] || 0) / 1000.0
      duration_seconds = (segment["duration"] || 0) / 1000.0
      end_time_seconds = start_time_seconds + duration_seconds

      {
        segment_index: index,
        text: segment["text"]&.strip,
        start_time: start_time_seconds,
        end_time: end_time_seconds,
        speaker: nil, # Supadata doesn't provide speaker info
        confidence: nil # Supadata doesn't provide confidence scores
      }
    end.select { |seg| seg[:text].present? }
  end
end
