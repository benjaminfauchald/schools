require 'net/http'
require 'uri'
require 'json'

class YoutubeService
  API_BASE_URL = 'https://www.googleapis.com/youtube/v3'
  CACHE_DURATION = 30.minutes
  MAX_RESULTS = 50
  
  def initialize(api_key = nil)
    @api_key = api_key || ENV['GOOGLE_YOUTUBE_API_KEY']
    raise "YouTube API key not configured" if @api_key.blank?
  end
  
  # Extract channel ID from various YouTube URL formats
  def extract_channel_id(youtube_url)
    return nil if youtube_url.blank?
    
    patterns = [
      # Direct channel ID: https://www.youtube.com/channel/UCxxxxxxxxxxxxxxxxxxxxxxx
      /youtube\.com\/channel\/([a-zA-Z0-9_-]{24})/,
      # Custom URL: https://www.youtube.com/c/channelname or https://www.youtube.com/@username
      /youtube\.com\/(?:c\/|@)([a-zA-Z0-9_-]+)/,
      # Legacy user URL: https://www.youtube.com/user/username
      /youtube\.com\/user\/([a-zA-Z0-9_-]+)/
    ]
    
    patterns.each do |pattern|
      match = youtube_url.match(pattern)
      if match
        identifier = match[1]
        # If it looks like a channel ID (24 characters starting with UC), return it
        return identifier if identifier.match(/^UC[a-zA-Z0-9_-]{22}$/)
        # Otherwise, resolve it to a channel ID
        return resolve_channel_id(identifier, youtube_url)
      end
    end
    
    nil
  end
  
  # Fetch videos and shorts from a YouTube channel
  def fetch_channel_videos(youtube_url, max_results: MAX_RESULTS)
    channel_id = extract_channel_id(youtube_url)
    return { success: false, error: "Could not extract channel ID from URL" } unless channel_id
    
    cache_key = "youtube_videos_#{channel_id}_#{max_results}"
    cached_result = Rails.cache.read(cache_key)
    return cached_result if cached_result
    
    begin
      # Get channel's uploads playlist
      uploads_playlist_id = get_uploads_playlist_id(channel_id)
      return { success: false, error: "Could not find uploads playlist" } unless uploads_playlist_id
      
      # Fetch videos from uploads playlist
      videos = fetch_playlist_items(uploads_playlist_id, max_results)
      
      result = {
        success: true,
        videos: videos,
        channel_id: channel_id,
        fetched_at: Time.current
      }
      
      Rails.cache.write(cache_key, result, expires_in: CACHE_DURATION)
      result
      
    rescue => e
      Rails.logger.error "YouTube API Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, error: e.message }
    end
  end
  
  private
  
  # Resolve custom username or handle to channel ID
  def resolve_channel_id(identifier, original_url)
    # Try search API first
    begin
      url = "#{API_BASE_URL}/search"
      params = {
        part: 'snippet',
        q: identifier,
        type: 'channel',
        maxResults: 1,
        key: @api_key
      }
      
      response = make_api_request(url, params)
      
      if response['items']&.any?
        return response['items'].first['snippet']['channelId']
      end
    rescue => e
      Rails.logger.warn "Failed to resolve channel ID via search: #{e.message}"
    end
    
    # If search fails, try channels API with forUsername (legacy)
    if identifier.match(/^[a-zA-Z0-9_-]+$/) # Simple username format
      begin
        url = "#{API_BASE_URL}/channels"
        params = {
          part: 'id',
          forUsername: identifier,
          key: @api_key
        }
        
        response = make_api_request(url, params)
        
        if response['items']&.any?
          return response['items'].first['id']
        end
      rescue => e
        Rails.logger.warn "Failed to resolve channel ID via forUsername: #{e.message}"
      end
    end
    
    nil
  end
  
  # Get the uploads playlist ID for a channel
  def get_uploads_playlist_id(channel_id)
    url = "#{API_BASE_URL}/channels"
    params = {
      part: 'contentDetails',
      id: channel_id,
      key: @api_key
    }
    
    response = make_api_request(url, params)
    
    if response['items']&.any?
      return response['items'].first.dig('contentDetails', 'relatedPlaylists', 'uploads')
    end
    
    nil
  end
  
  # Fetch videos from a playlist
  def fetch_playlist_items(playlist_id, max_results)
    videos = []
    next_page_token = nil
    
    loop do
      url = "#{API_BASE_URL}/playlistItems"
      params = {
        part: 'snippet,contentDetails',
        playlistId: playlist_id,
        maxResults: [max_results - videos.length, 50].min, # API max is 50 per request
        key: @api_key
      }
      params[:pageToken] = next_page_token if next_page_token
      
      response = make_api_request(url, params)
      
      if response['items']&.any?
        video_items = response['items'].map do |item|
          process_video_item(item)
        end
        
        videos.concat(video_items)
      end
      
      next_page_token = response['nextPageToken']
      break if next_page_token.nil? || videos.length >= max_results
    end
    
    # Get additional video details for duration, view count, etc.
    enhance_video_details(videos)
  end
  
  # Process individual video item from playlist
  def process_video_item(item)
    snippet = item['snippet']
    
    {
      video_id: snippet['resourceId']['videoId'],
      title: snippet['title'],
      description: snippet['description'],
      thumbnail_url: snippet.dig('thumbnails', 'high', 'url') || 
                     snippet.dig('thumbnails', 'medium', 'url') ||
                     snippet.dig('thumbnails', 'default', 'url'),
      published_at: snippet['publishedAt'],
      channel_title: snippet['channelTitle'],
      position: item.dig('contentDetails', 'note') # For playlist ordering
    }
  end
  
  # Enhance videos with additional details (duration, views, etc.)
  def enhance_video_details(videos)
    return videos if videos.empty?
    
    video_ids = videos.map { |v| v[:video_id] }.join(',')
    
    url = "#{API_BASE_URL}/videos"
    params = {
      part: 'statistics,contentDetails',
      id: video_ids,
      key: @api_key
    }
    
    begin
      response = make_api_request(url, params)
      
      if response['items']&.any?
        stats_by_id = response['items'].each_with_object({}) do |item, hash|
          hash[item['id']] = {
            duration: item.dig('contentDetails', 'duration'),
            view_count: item.dig('statistics', 'viewCount'),
            like_count: item.dig('statistics', 'likeCount'),
            comment_count: item.dig('statistics', 'commentCount')
          }
        end
        
        videos.each do |video|
          if stats = stats_by_id[video[:video_id]]
            video.merge!(stats)
          end
        end
      end
    rescue => e
      Rails.logger.warn "Failed to fetch video statistics: #{e.message}"
    end
    
    videos
  end
  
  # Make HTTP request to YouTube API
  def make_api_request(url, params)
    uri = URI(url)
    uri.query = URI.encode_www_form(params)
    
    response = Net::HTTP.get_response(uri)
    
    unless response.is_a?(Net::HTTPSuccess)
      raise "API request failed: #{response.code} #{response.message}"
    end
    
    JSON.parse(response.body)
  end
  
  # Parse YouTube duration format (PT4M13S) to human readable
  def self.parse_duration(duration)
    return nil if duration.blank?
    
    match = duration.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/)
    return nil unless match
    
    hours = match[1].to_i
    minutes = match[2].to_i
    seconds = match[3].to_i
    
    if hours > 0
      "#{hours}:#{minutes.to_s.rjust(2, '0')}:#{seconds.to_s.rjust(2, '0')}"
    else
      "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
    end
  end
  
  # Format view count for display
  def self.format_view_count(count)
    return "0 views" if count.blank? || count.to_i == 0
    
    count = count.to_i
    if count >= 1_000_000
      "#{(count / 1_000_000.0).round(1)}M views"
    elsif count >= 1_000
      "#{(count / 1_000.0).round(1)}K views"
    else
      "#{count} views"
    end
  end
  
  # Fetch videos and extract transcripts for a place
  def fetch_and_process_transcripts(place, youtube_url, options = {})
    max_results = options[:max_results] || MAX_RESULTS
    extract_transcripts = options.fetch(:extract_transcripts, true)
    
    # Fetch videos from channel
    videos_result = fetch_channel_videos(youtube_url, max_results: max_results)
    return videos_result unless videos_result[:success]
    
    videos = videos_result[:videos]
    
    result = {
      success: true,
      place_id: place.id,
      place_name: place.name,
      channel_id: videos_result[:channel_id],
      total_videos: videos.length,
      processed_videos: 0,
      transcript_extraction_queued: false
    }
    
    if extract_transcripts && videos.any?
      # Queue transcript extraction job
      YoutubeTranscriptExtractionJob.perform_later(
        place.id,
        videos,
        {
          delay: options[:api_delay] || 2, # Seconds between API calls
          force_refresh: options[:force_refresh] || false,
          store_results: true
        }
      )
      
      result[:transcript_extraction_queued] = true
      result[:message] = "Queued #{videos.length} videos for transcript extraction"
      
      Rails.logger.info "Queued transcript extraction for #{videos.length} videos from #{place.name}"
    end
    
    result
  end
  
  # Extract video ID from various YouTube URL formats
  def self.extract_video_id(url)
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
  
  # Check if a place has YouTube content ready for processing
  def channel_stats(place)
    return { success: false, error: "Place has no YouTube URL" } if place.youtube_url.blank?
    
    videos_result = fetch_channel_videos(place.youtube_url, max_results: 5)
    return videos_result unless videos_result[:success]
    
    existing_transcripts = place.transcripts.count
    processed_transcripts = place.transcripts.processed.count
    
    {
      success: true,
      channel_has_videos: videos_result[:videos].any?,
      sample_videos: videos_result[:videos].first(3),
      existing_transcripts: existing_transcripts,
      processed_transcripts: processed_transcripts,
      processing_completion: existing_transcripts > 0 ? (processed_transcripts.to_f / existing_transcripts * 100).round(1) : 0
    }
  end
end