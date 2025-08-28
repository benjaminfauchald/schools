# MediaItem model manages photos, videos, documents, and other media assets for places
# Supports different media types with sorting and categorization for any place type
class MediaItem < ApplicationRecord
  belongs_to :place
  
  validates :kind, presence: true, inclusion: { 
    in: %w[logo campus_photo brochure fee_schedule_pdf video virtual_tour menu floor_plan]
  }
  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :sort_order, numericality: { greater_than_or_equal_to: 0 }
  
  scope :by_kind, ->(kind) { where(kind: kind) }
  scope :ordered, -> { order(:sort_order, :created_at) }
  scope :photos, -> { where(kind: 'campus_photo') }
  scope :documents, -> { where(kind: %w[brochure fee_schedule_pdf]) }
  scope :videos, -> { where(kind: %w[video virtual_tour]) }
  
  # Check if this is an image
  def image?
    %w[logo campus_photo].include?(kind)
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
    when 'campus_photo'
      "#{place.name} campus photo"
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
    when 'campus_photo'
      'Campus Photo'
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
end