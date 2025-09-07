# frozen_string_literal: true

class Schools::VideoGalleryComponent < ViewComponent::Base
  def initialize(school:)
    @school = school
  end

  private

  attr_reader :school

  def render?
    videos.any?
  end

  def videos
    @videos ||= school.visible_youtube_videos
  end

  def video_count
    videos.count
  end

  def gallery_id
    "video-gallery-#{object_id}"
  end

  def modal_id
    "video-modal-#{object_id}"
  end

  def carousel_id
    "video-carousel-#{object_id}"
  end

  def youtube_thumbnail_url(video)
    video_id = video[:video_id] || video["video_id"]
    "https://img.youtube.com/vi/#{video_id}/hqdefault.jpg"
  end

  def youtube_embed_url(video)
    video_id = video[:video_id] || video["video_id"]
    "https://www.youtube.com/embed/#{video_id}?autoplay=1&rel=0"
  end

  def video_title(video)
    video[:title] || video["title"] || "Video"
  end

  def video_description(video)
    description = video[:description] || video["description"] || ""
    description.length > 100 ? "#{description[0..97]}..." : description
  end
end
