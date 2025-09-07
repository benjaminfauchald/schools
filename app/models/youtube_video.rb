class YoutubeVideo < ApplicationRecord
  belongs_to :place

  validates :video_id, presence: true, uniqueness: { scope: :place_id }
  validates :title, presence: true
  validates :thumbnail_url, presence: true

  scope :visible, -> { where(visible: true) }
  scope :ordered, -> { order(:sort_order, :created_at) }
  scope :recent, -> { order(created_at: :desc) }

  # Transcript association through place
  has_one :transcript, -> { where("transcripts.video_id = youtube_videos.video_id") },
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
    video_data&.dig("duration")
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
    transcript_record&.status || "not_started"
  end

  def transcript_available?
    # Check if video likely has captions (heuristics)
    true # Most YouTube videos have auto-generated captions
  end

  def queue_transcript_processing(options = {})
    return false unless transcript_available?

    Rails.logger.info "📝 Queuing transcript processing for video #{video_id}: #{title}"

    ProcessVideoTranscriptJob.perform_later(id, place_id, options)
    true
  end

  def transcript_processing_status
    transcript = transcript_record
    base_status = case transcript_status
    when "completed"
      if transcript&.ai_enabled?
        { status: "completed", message: "Transcript used for AI", badge_class: "success" }
      else
        { status: "completed_disabled", message: "Transcript not used for AI", badge_class: "secondary" }
      end
    when "processing"
      # Check if processing job is stuck (processing for more than 10 minutes)
      if transcript && transcript.updated_at < 10.minutes.ago
        { status: "failed", message: "Processing timed out", badge_class: "error" }
      else
        processing_time = transcript ? ((Time.current - transcript.updated_at) / 60).round(0) : 0
        message = processing_time > 0 ? "Processing (#{processing_time}m)..." : "Processing transcript..."
        { status: "processing", message: message, badge_class: "warning" }
      end
    when "failed"
      { status: "failed", message: "Transcript failed", badge_class: "error" }
    when "no_transcript"
      { status: "no_transcript", message: "No transcript", badge_class: "secondary" }
    when "pending"
      { status: "pending", message: "Transcript queued", badge_class: "info" }
    else
      { status: "not_started", message: "No transcript", badge_class: "secondary" }
    end

    # Add AI enablement info for completed transcripts
    if transcript&.completed?
      base_status[:ai_enabled] = transcript.ai_enabled?
      base_status[:can_toggle] = true
    end

    base_status
  end

  def can_retry_transcript?
    status = transcript_status
    return true if [ "failed", "not_started" ].include?(status)

    # Allow retry if processing job has timed out (stuck for more than 10 minutes)
    if status == "processing" && transcript_record && transcript_record.updated_at < 10.minutes.ago
      return true
    end

    # Don't allow retry for videos that legitimately have no transcript
    return false if status == "no_transcript"

    false
  end

  def transcript_segments_count
    transcript_record&.transcript_segments&.count || 0
  end
end
