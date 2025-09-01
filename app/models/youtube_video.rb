class YoutubeVideo < ApplicationRecord
  belongs_to :place
  
  validates :video_id, presence: true, uniqueness: { scope: :place_id }
  validates :title, presence: true
  validates :thumbnail_url, presence: true
  
  scope :visible, -> { where(visible: true) }
  scope :ordered, -> { order(:sort_order, :created_at) }
  scope :recent, -> { order(created_at: :desc) }
  
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
end
