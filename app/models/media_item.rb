# MediaItem model manages photos, videos, documents, and other media assets for places
# Supports different media types with sorting and categorization for any place type
class MediaItem < ApplicationRecord
  belongs_to :place
  
  # Add file attachment capability for uploaded media
  has_one_attached :file
  
  validates :kind, presence: true, inclusion: { 
    in: %w[logo photo brochure fee_schedule_pdf video virtual_tour menu floor_plan]
  }
  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, unless: -> { file.attached? }
  validates :file, presence: true, unless: -> { url.present? }
  validates :sort_order, numericality: { greater_than_or_equal_to: 0 }
  
  # Add source enum to track where media came from
  enum :source, {
    google_places: 'google_places',
    school_upload: 'school_upload',
    admin_upload: 'admin_upload'
  }, prefix: 'from'
  
  scope :by_kind, ->(kind) { where(kind: kind) }
  scope :ordered, -> { order(:sort_order, :created_at) }
  scope :photos, -> { where(kind: 'photo') }
  scope :uploaded_photos, -> { where(kind: 'photo').where.not(source: 'google_places') }
  scope :google_photos, -> { where(kind: 'photo', source: 'google_places') }
  scope :documents, -> { where(kind: %w[brochure fee_schedule_pdf]) }
  scope :videos, -> { where(kind: %w[video virtual_tour]) }
  
  # Check if this is an image
  def image?
    %w[logo photo].include?(kind)
  end
  
  # Check if this is a document
  def document?
    %w[brochure fee_schedule_pdf menu floor_plan].include?(kind)
  end
  
  # Check if this is a video
  def video?
    %w[video virtual_tour].include?(kind)
  end
  
  # Get file extension from URL
  def file_extension
    return nil unless url.present?
    File.extname(URI.parse(url).path).downcase.gsub('.', '')
  rescue URI::InvalidURIError
    nil
  end
  
  # Generate alt text if not provided
  def display_alt_text
    return alt_text if alt_text.present?
    
    case kind
    when 'logo'
      "#{place.name} logo"
    when 'photo'
      "#{place.name} photo"
    when 'brochure'
      "#{place.name} brochure"
    when 'fee_schedule_pdf'
      "#{place.name} fee schedule"
    when 'video', 'virtual_tour'
      "#{place.name} virtual tour"
    else
      "#{place.name} #{kind.humanize.downcase}"
    end
  end
  
  # Get human-readable kind name
  def kind_display
    case kind
    when 'photo'
      'Photo'
    when 'fee_schedule_pdf'
      'Fee Schedule'
    when 'virtual_tour'
      'Virtual Tour'
    else
      kind.humanize
    end
  end
  
  # Check if URL is accessible (basic validation)
  def url_accessible?
    return false unless url.present?
    
    begin
      uri = URI.parse(url)
      uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      false
    end
  end
  
  # Get the display URL for images (either attached file or URL)
  def image_url
    if file.attached?
      Rails.application.routes.url_helpers.rails_blob_url(file, only_path: false)
    else
      url
    end
  end
  
  # Get display URL for thumbnails
  def thumbnail_url(size: 300)
    if file.attached? && image?
      Rails.application.routes.url_helpers.rails_representation_url(
        file.variant(resize_to_limit: [size, size]), 
        only_path: false
      )
    else
      url
    end
  end
  
  # Check if this is an uploaded file vs URL reference
  def uploaded?
    file.attached?
  end
end