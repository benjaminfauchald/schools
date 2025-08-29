class Page < ApplicationRecord
  belongs_to :school
  
  validates :title, presence: true, length: { maximum: 255 }
  validates :content, presence: true
  validates :slug, presence: true, uniqueness: { scope: :school_id }
  validates :page_type, presence: true
  validates :status, inclusion: { in: %w[draft published archived] }
  
  # Flexible page types - can be any string value
  scope :by_type, ->(type) { where(page_type: type) }
  
  # Convenience scopes for common page types
  scope :about_us, -> { where(page_type: 'about_us') }
  scope :blog, -> { where(page_type: 'blog') }
  scope :academics, -> { where(page_type: 'academics') }
  scope :sports, -> { where(page_type: 'sports') }
  scope :activities, -> { where(page_type: 'activities') }
  
  enum :status, {
    draft: 'draft',
    published: 'published',
    archived: 'archived'
  }
  
  before_validation :generate_slug, if: -> { title.present? && slug.blank? }
  before_save :set_published_at, if: -> { status_changed? && published? }
  
  scope :published, -> { where(status: 'published') }
  scope :recent, -> { order(published_at: :desc, created_at: :desc) }
  scope :sorted, -> { order(:sort_order, :title) }
  
  def published?
    status == 'published'
  end
  
  def generate_meta_description
    return meta_description if meta_description.present?
    
    # Extract first 160 characters from content, stripping HTML
    stripped_content = ActionView::Base.full_sanitizer.sanitize(content)
    truncated = stripped_content.truncate(160, separator: ' ')
    truncated
  end
  
  def to_param
    slug
  end
  
  private
  
  def generate_slug
    base_slug = title.parameterize
    counter = 1
    candidate_slug = base_slug
    
    while school.pages.where(slug: candidate_slug).where.not(id: id).exists?
      candidate_slug = "#{base_slug}-#{counter}"
      counter += 1
    end
    
    self.slug = candidate_slug
  end
  
  def set_published_at
    self.published_at = Time.current if published_at.blank?
  end
end
