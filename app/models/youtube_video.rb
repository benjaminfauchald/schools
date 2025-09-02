class YoutubeVideo < ApplicationRecord
  belongs_to :place
  
  validates :video_id, presence: true, uniqueness: { scope: :place_id }
  validates :title, presence: true
  validates :thumbnail_url, presence: true
  
  scope :visible, -> { where(visible: true) }
  scope :ordered, -> { order(:sort_order, :created_at) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Transcript association through place
  has_one :transcript, -> { where('transcripts.video_id = youtube_videos.video_id') }, 
          through: :place, source: :transcripts
  
  # Direct transcript segments association for joins (using a simpler approach)
  has_many :transcript_segments, through: :transcript
  
  # Get YouTube video URL
  def youtube_url
    "https://www.youtube.com/watch?v=#{video_id}"
  end
  
  # Get YouTube embed URL
  def youtube_embed_url
    "https://www.youtube.com/embed/#{video_id}?autoplay=1&rel=0"
  end
  
  # Get high quality thumbnail URL
  def hq_thumbnail_url
    "https://img.youtube.com/vi/#{video_id}/hqdefault.jpg"
  end
  
  # Generate video key for visibility settings compatibility
  def video_key
    video_id
  end
  
  # Format duration for display
  def duration_display
    return duration if duration.present?
    video_data&.dig('duration')
  end
  
  # Format view count for display
  def view_count_display
    return unless view_count.present?
    
    if view_count >= 1_000_000
      "#{(view_count / 1_000_000.0).round(1)}M views"
    elsif view_count >= 1_000
      "#{(view_count / 1_000.0).round(1)}K views"
    else
      "#{view_count} views"
    end
  end
  
  # Transcript-related methods
  
  def transcript_record
    place.transcripts.find_by(video_id: video_id)
  end
  
  def has_transcript?
    transcript_record&.completed? || false
  end
  
  def transcript_status
    transcript_record&.status || 'not_started'
  end
  
  def transcript_available?
    # Check if video likely has captions (heuristics)
    return true # Most YouTube videos have auto-generated captions
  end
  
  def queue_transcript_processing(options = {})
    return false unless transcript_available?
    
    Rails.logger.info "📝 Queuing transcript processing for video #{video_id}: #{title}"
    
    ProcessVideoTranscriptJob.perform_later(id, place_id, options)
    true
  end
  
  def transcript_processing_status
    case transcript_status
    when 'completed'
      { status: 'completed', message: 'Transcript available', badge_class: 'success' }
    when 'processing'
      # Check if processing job is stuck (processing for more than 10 minutes)
      if transcript_record && transcript_record.updated_at < 10.minutes.ago
        { status: 'failed', message: 'Processing timed out', badge_class: 'error' }
      else
        processing_time = transcript_record ? ((Time.current - transcript_record.updated_at) / 60).round(0) : 0
        message = processing_time > 0 ? "Processing (#{processing_time}m)..." : "Processing transcript..."
        { status: 'processing', message: message, badge_class: 'warning' }
      end
    when 'failed'
      { status: 'failed', message: 'Transcript failed', badge_class: 'error' }
    when 'pending'
      { status: 'pending', message: 'Transcript queued', badge_class: 'info' }
    else
      { status: 'not_started', message: 'No transcript', badge_class: 'secondary' }
    end
  end
  
  def can_retry_transcript?
    status = transcript_status
    return true if ['failed', 'not_started'].include?(status)
    
    # Allow retry if processing job has timed out (stuck for more than 10 minutes)
    if status == 'processing' && transcript_record && transcript_record.updated_at < 10.minutes.ago
      return true
    end
    
    false
  end
  
  def transcript_segments_count
    transcript_record&.transcript_segments&.count || 0
  end
end
