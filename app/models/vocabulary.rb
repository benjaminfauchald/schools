# Vocabulary model defines taxonomy categories like curriculum, accreditation, facility, etc.
# Each vocabulary contains a collection of related terms that can be assigned to places
class Vocabulary < ApplicationRecord
  has_many :terms, dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :label, presence: true

  scope :ordered, -> { order(:label) }

  def to_param
    code
  end

  # Get all active terms in this vocabulary
  def active_terms
    terms.active
  end

  # Count of active terms
  def terms_count
    terms.active.count
  end

  # Usage count across all places
  def usage_count
    terms.joins(:taggings).select(:id).distinct.count
  end
end
