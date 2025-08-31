require 'net/http'
require 'uri'
require 'json'
require 'timeout'

class YoutubeTranscriptService
  API_BASE_URL = 'https://api.supadata.ai/v1'
  
  def initialize(api_key = nil)
    @api_key = api_key || ENV['SUPADATA_API_KEY']
    raise "Supadata API key not configured. Please set SUPADATA_API_KEY environment variable." if @api_key.blank?
  end
  
  # Extract transcript from YouTube video
  def extract_transcript(video_id, options = {})
    return { success: false, error: "Video ID is required" } if video_id.blank?
    
    begin
      # Build YouTube URL from video ID
      youtube_url = build_youtube_url(video_id)
      
      # Make GET request to transcript endpoint
      url = "#{API_BASE_URL}/transcript"
      params = { url: youtube_url }
      
      response = make_api_request(url, params)
      
      # Parse the response - Supadata returns transcript data directly
      result = {
        success: true,
        video_id: video_id,
        extracted_at: Time.current
      }
      
      # Handle the response based on its structure
      if response.is_a?(Hash)
        # Parse Supadata response format
        if response['transcript']
          # Direct transcript array with segments
          segments_data = response['transcript']
          if segments_data.is_a?(Array)
            segments = segments_data.map.with_index do |segment, index|
              parse_transcript_segment(segment, index)
            end
            
            result[:segments] = segments
            result[:transcript_text] = segments.map { |s| s[:text] }.join(' ')
            result[:format] = 'segments'
            result[:total_segments] = segments.length
            result[:duration] = calculate_total_duration(segments)
            result[:language] = response['lang']
            result[:available_languages] = response['availableLangs']
          else
            result[:transcript_text] = segments_data.to_s
            result[:format] = 'text'
          end
        elsif response['lang'] && response.keys.any? { |k| k != 'lang' && k != 'availableLangs' }
          # Supadata format with language data and transcript segments
          # Extract the transcript data (usually under a language key)
          transcript_data = response.reject { |k, v| ['lang', 'availableLangs'].include?(k) }.values.first
          
          if transcript_data.is_a?(Array)
            segments = transcript_data.map.with_index do |segment, index|
              parse_transcript_segment(segment, index)
            end
            
            result[:segments] = segments
            result[:transcript_text] = segments.map { |s| s[:text] }.join(' ')
            result[:format] = 'segments'
            result[:total_segments] = segments.length
            result[:duration] = calculate_total_duration(segments)
            result[:language] = response['lang']
            result[:available_languages] = response['availableLangs']
          else
            # Try to extract text from the structure
            all_text = extract_text_from_structure(response)
            result[:transcript_text] = all_text
            result[:format] = 'text'
            result[:language] = response['lang']
          end
        elsif response['text']
          result[:transcript_text] = response['text']
          result[:format] = 'text'
        else
          # Handle other structured responses
          all_text = extract_text_from_structure(response)
          result[:transcript_text] = all_text
          result[:format] = 'parsed'
        end
      elsif response.is_a?(String)
        # Direct text response
        result[:transcript_text] = response
        result[:format] = 'text'
      else
        result[:raw_content] = response
        result[:format] = 'unknown'
      end
      
      result
      
    rescue => e
      Rails.logger.error "Supadata API Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      {
        success: false,
        error: "Failed to extract transcript: #{e.message}",
        video_id: video_id
      }
    end
  end
  
  # Extract transcript and create Transcript record
  def extract_and_create_transcript(place, video_data, options = {})
    video_id = extract_video_id_from_data(video_data)
    return { success: false, error: "Could not extract video ID" } unless video_id
    
    # Check if transcript already exists
    existing_transcript = Transcript.find_by(place: place, youtube_video_id: video_id)
    if existing_transcript && !options[:force_refresh]
      return {
        success: true,
        transcript: existing_transcript,
        message: "Transcript already exists"
      }
    end
    
    # Extract transcript from API
    extraction_result = extract_transcript(video_id, options)
    return extraction_result unless extraction_result[:success]
    
    begin
      # Create or update transcript record
      transcript_data = {
        place: place,
        video_title: video_data[:title] || video_data['title'] || "YouTube Video #{video_id}",
        video_url: "https://www.youtube.com/watch?v=#{video_id}",
        youtube_video_id: video_id,
        full_transcript_text: extraction_result[:transcript_text],
        primary_language: options[:language] || 'en',
        total_duration_ms: extraction_result[:duration],
        segment_count: extraction_result[:total_segments] || 0
      }
      
      transcript = if existing_transcript
        existing_transcript.update!(transcript_data)
        existing_transcript
      else
        Transcript.create!(transcript_data)
      end
      
      # Create transcript segments if available
      if extraction_result[:segments].present?
        create_transcript_segments(transcript, extraction_result[:segments])
      end
      
      # Mark as processed
      transcript.mark_as_processed!
      
      {
        success: true,
        transcript: transcript,
        segments_created: extraction_result[:segments]&.length || 0,
        message: "Transcript successfully extracted and saved"
      }
      
    rescue ActiveRecord::RecordInvalid => e
      {
        success: false,
        error: "Failed to save transcript: #{e.record.errors.full_messages.join(', ')}"
      }
    rescue => e
      Rails.logger.error "Failed to create transcript record: #{e.message}"
      {
        success: false,
        error: "Failed to save transcript: #{e.message}"
      }
    end
  end
  
  # Batch process multiple videos for a place
  def extract_transcripts_for_place(place, video_list, options = {})
    results = {
      success: true,
      total_videos: video_list.length,
      processed: 0,
      created: 0,
      updated: 0,
      skipped: 0,
      errors: []
    }
    
    video_list.each_with_index do |video_data, index|
      Rails.logger.info "Processing video #{index + 1}/#{video_list.length}: #{video_data[:title] || video_data['title']}"
      
      begin
        result = extract_and_create_transcript(place, video_data, options)
        
        if result[:success]
          results[:processed] += 1
          if result[:message].include?("already exists")
            results[:skipped] += 1
          elsif result[:transcript].created_at == result[:transcript].updated_at
            results[:created] += 1
          else
            results[:updated] += 1
          end
        else
          results[:errors] << {
            video: video_data[:title] || video_data['title'] || video_data[:video_id],
            error: result[:error]
          }
        end
        
        # Rate limiting - be respectful to the API
        sleep(options[:delay] || 1) if index < video_list.length - 1
        
      rescue => e
        Rails.logger.error "Error processing video #{video_data[:title] || 'unknown'}: #{e.message}"
        results[:errors] << {
          video: video_data[:title] || video_data['title'] || 'unknown',
          error: e.message
        }
      end
    end
    
    results[:success] = results[:errors].empty?
    results
  end
  
  # Utility method to test API connectivity
  def test_connection
    begin
      # Test with a known working video ID
      result = extract_transcript("dQw4w9WgXcQ", text_only: true, include_segments: false)
      {
        success: result[:success],
        message: result[:success] ? "Connection successful" : result[:error]
      }
    rescue => e
      {
        success: false,
        message: "Connection failed: #{e.message}"
      }
    end
  end
  
  private
  
  def make_api_request(url, params)
    # Build URI with query parameters
    uri = URI(url)
    uri.query = URI.encode_www_form(params) if params
    
    begin
      Rails.logger.info "Making GET request to #{uri}"
      
      # Add timeout handling for the HTTP request
      response = Timeout::timeout(30) do
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if uri.scheme == 'https'
        http.read_timeout = 30
        http.open_timeout = 10
        
        request = Net::HTTP::Get.new(uri)
        request['x-api-key'] = @api_key  # Supadata uses x-api-key header
        
        http.request(request)
      end
      
      Rails.logger.info "Response: #{response.code} - #{response.body[0..500]}..."
      
      unless response.is_a?(Net::HTTPSuccess)
        error_message = "API request failed: #{response.code} #{response.message}"
        
        # Try to parse error response
        begin
          error_body = JSON.parse(response.body)
          error_message += " - #{error_body['error'] || error_body['message']}" if error_body.is_a?(Hash)
        rescue JSON::ParserError
          error_message += " - #{response.body.truncate(200)}"
        end
        
        raise error_message
      end
      
      # Try to parse as JSON, if it fails return as string
      begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        response.body
      end
      
    rescue Timeout::Error => e
      raise "Request timeout: #{e.message}"
    rescue => e
      Rails.logger.error "Supadata API request error: #{e.class} - #{e.message}"
      raise e
    end
  end
  
  def build_youtube_url(video_id)
    if video_id.start_with?('http')
      video_id  # Already a full URL
    else
      "https://youtu.be/#{video_id}"
    end
  end
  
  def extract_text_from_structure(data)
    text_parts = []
    
    case data
    when Hash
      data.each do |key, value|
        next if ['lang', 'availableLangs'].include?(key)
        
        if value.is_a?(Array)
          # Process array of segments
          value.each do |item|
            if item.is_a?(Hash) && item['text']
              text_parts << item['text']
            elsif item.is_a?(String)
              text_parts << item
            end
          end
        elsif value.is_a?(String)
          text_parts << value
        end
      end
    when Array
      data.each do |item|
        if item.is_a?(Hash) && item['text']
          text_parts << item['text']
        elsif item.is_a?(String)
          text_parts << item
        end
      end
    when String
      text_parts << data
    end
    
    text_parts.join(' ').strip
  end
  
  def parse_transcript_segment(segment_data, index)
    # Handle different possible segment formats from Supadata
    if segment_data.is_a?(Hash)
      # Supadata format has 'text', 'offset', 'duration' (offset is start time in ms)
      start_time = segment_data['offset'] || segment_data['start'] || segment_data[:start] || segment_data[:offset] || 0
      duration = segment_data['duration'] || segment_data[:duration] || 0
      
      {
        sequence_number: index,
        text: segment_data['text'] || segment_data[:text] || '',
        offset_ms: start_time.is_a?(Numeric) ? start_time.to_i : parse_timestamp_to_ms(start_time),
        duration_ms: duration.is_a?(Numeric) ? duration.to_i : parse_timestamp_to_ms(duration),
        confidence: segment_data['confidence'] || segment_data[:confidence],
        raw_data: segment_data
      }
    elsif segment_data.is_a?(String)
      # Plain text segment without timestamps
      {
        sequence_number: index,
        text: segment_data,
        offset_ms: 0,
        duration_ms: 0,
        raw_data: { text: segment_data }
      }
    else
      {
        sequence_number: index,
        text: segment_data.to_s,
        offset_ms: 0,
        duration_ms: 0,
        raw_data: segment_data
      }
    end
  end
  
  def parse_timestamp_to_ms(timestamp)
    return 0 if timestamp.blank?
    
    if timestamp.is_a?(Numeric)
      # Already in seconds, convert to milliseconds
      (timestamp * 1000).to_i
    elsif timestamp.is_a?(String)
      # Parse various time formats: "1:23", "1:23.456", "83.456", etc.
      if timestamp.match(/(\d+):(\d+)(?:\.(\d+))?/)
        minutes, seconds, decimal = $1.to_i, $2.to_i, $3.to_i
        ((minutes * 60 + seconds) * 1000 + decimal * 10).to_i
      elsif timestamp.match(/(\d+)\.(\d+)/)
        seconds, decimal = $1.to_i, $2.to_i
        (seconds * 1000 + decimal * 10).to_i
      else
        timestamp.to_f * 1000
      end
    else
      0
    end
  end
  
  def calculate_total_duration(segments)
    return 0 if segments.empty?
    
    last_segment = segments.max_by { |s| s[:offset_ms] + s[:duration_ms] }
    last_segment[:offset_ms] + last_segment[:duration_ms]
  end
  
  def extract_video_id_from_data(video_data)
    if video_data.is_a?(Hash)
      video_data[:video_id] || video_data['video_id'] || 
      video_data[:youtube_video_id] || video_data['youtube_video_id']
    elsif video_data.is_a?(String)
      # Assume it's already a video ID or URL
      extract_video_id_from_url(video_data)
    else
      nil
    end
  end
  
  def extract_video_id_from_url(url)
    return url if url.match(/^[a-zA-Z0-9_-]{11}$/) # Already a video ID
    
    patterns = [
      /(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([a-zA-Z0-9_-]{11})/,
      /youtube\.com\/v\/([a-zA-Z0-9_-]{11})/
    ]
    
    patterns.each do |pattern|
      match = url.match(pattern)
      return match[1] if match
    end
    
    nil
  end
  
  def create_transcript_segments(transcript, segments_data)
    # Delete existing segments if we're updating
    transcript.transcript_segments.destroy_all
    
    segments_data.each do |segment_data|
      TranscriptSegment.create!(
        transcript: transcript,
        sequence_number: segment_data[:sequence_number],
        text: segment_data[:text],
        offset_ms: segment_data[:offset_ms],
        duration_ms: segment_data[:duration_ms],
        confidence: segment_data[:confidence],
        raw_segment_data: segment_data[:raw_data]
      )
    end
    
    transcript.update!(segment_count: segments_data.length)
  end
end