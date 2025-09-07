# Term model represents individual tags within vocabularies with support for hierarchy and metadata
# Examples: curriculum > ib_dp, accreditation > cis, facility > swimming_pool
class Term < ApplicationRecord
  belongs_to :vocabulary
  belongs_to :parent, class_name: "Term", optional: true
  has_many :children, class_name: "Term", foreign_key: :parent_id, dependent: :destroy
  has_many :taggings, dependent: :destroy
  has_many :schools, through: :taggings, source: :taggable, source_type: "School"

  validates :slug, presence: true, uniqueness: { scope: :vocabulary_id }
  validates :label, presence: true
  validates :vocabulary_id, presence: true

  # Ensure parent belongs to same vocabulary
  validates :parent_id, inclusion: {
    in: ->(term) { term.vocabulary&.terms&.pluck(:id) || [] },
    message: "must belong to the same vocabulary"
  }, allow_nil: true

  scope :active, -> { where(is_active: true) }
  scope :roots, -> { where(parent_id: nil) }
  scope :in_vocabulary, ->(vocab_code) { joins(:vocabulary).where(vocabularies: { code: vocab_code }) }
  scope :search, ->(query) { where("label ILIKE ? OR slug ILIKE ?", "%#{query}%", "%#{query}%") }

  before_validation :generate_slug, if: -> { slug.blank? && label.present? }

  def to_param
    slug
  end

  # Full path for hierarchical terms (e.g., "STEM > Robotics")
  def full_label
    return label if parent.nil?
    "#{parent.full_label} > #{label}"
  end

  # Get all ancestor terms
  def ancestors
    return Term.none if parent.nil?
    Term.where(id: parent.id).includes(:parent) + parent.ancestors
  end

  # Get all descendant terms (recursive)
  def descendants
    Term.where(parent_id: id).includes(:children).flat_map do |child|
      [ child ] + child.descendants
    end
  end

  # Check if term is currently valid (for date-bounded terms like accreditations)
  def valid_at?(date = Date.current)
    taggings.where(
      "(valid_from IS NULL OR valid_from <= ?) AND (valid_to IS NULL OR valid_to >= ?)",
      date, date
    ).exists?
  end

  # Count of schools using this term
  def schools_count
    schools.published.count
  end

  # Metadata helpers
  def stage
    metadata["stage"]
  end

  def issuer
    metadata["issuer"]
  end

  def category
    metadata["category"]
  end

  private

  def generate_slug
    self.slug = label.parameterize.underscore
  end
end
