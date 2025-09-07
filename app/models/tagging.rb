# Tagging model provides polymorphic association between terms and any taggable entity (schools, places, etc.)
# Supports temporal validity for time-bound metadata like accreditations with expiry dates
class Tagging < ApplicationRecord
  belongs_to :term
  belongs_to :taggable, polymorphic: true

  validates :term_id, presence: true
  validates :taggable_type, :taggable_id, presence: true
  validates :context, presence: true

  # Critical validation: context must match vocabulary code
  validate :context_matches_vocabulary_code

  # Prevent duplicate taggings
  validates :term_id, uniqueness: {
    scope: [ :taggable_type, :taggable_id, :context ],
    message: "already tagged with this term in this context"
  }

  scope :valid_at, ->(date = Date.current) {
    where(
      "(valid_from IS NULL OR valid_from <= ?) AND (valid_to IS NULL OR valid_to >= ?)",
      date, date
    )
  }

  scope :by_context, ->(context) { where(context: context) }
  scope :for_school, ->(school_id) { where(taggable_type: "School", taggable_id: school_id) }

  # Check if tagging is currently valid
  def valid_at?(date = Date.current)
    (valid_from.nil? || valid_from <= date) &&
    (valid_to.nil? || valid_to >= date)
  end

  def currently_valid?
    valid_at?(Date.current)
  end

  # Expire the tagging
  def expire!(date = Date.current)
    update!(valid_to: date)
  end

  # Vocabulary shortcut
  def vocabulary
    term.vocabulary
  end

  private

  def context_matches_vocabulary_code
    return unless term&.vocabulary

    unless context == term.vocabulary.code
      errors.add(:context, "must match vocabulary code '#{term.vocabulary.code}'")
    end
  end
end
