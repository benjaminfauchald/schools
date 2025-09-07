# SchoolFeeBand model defines grade-specific tuition within a fee schedule
# Allows different pricing tiers based on grade levels (e.g., Elementary vs High School)
class SchoolFeeBand < ApplicationRecord
  belongs_to :school_fee_schedule

  validates :grade_from, :grade_to, :annual_tuition, presence: true
  validates :grade_from, :grade_to, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 12 }
  validates :annual_tuition, numericality: { greater_than: 0 }
  validates :grade_from, uniqueness: {
    scope: [ :school_fee_schedule_id, :grade_to ],
    message: "overlaps with existing grade band"
  }

  validate :grade_to_greater_than_from
  validate :no_overlapping_bands

  scope :ordered, -> { order(:grade_from) }
  scope :covering_grade, ->(grade) { where("grade_from <= ? AND grade_to >= ?", grade, grade) }

  # Get grade range as display string
  def grade_range_display
    if grade_from == grade_to
      "Grade #{grade_from}"
    else
      "Grades #{grade_from}-#{grade_to}"
    end
  end

  # Get tuition with currency
  def tuition_display
    currency = school_fee_schedule.currency
    "#{formatted_amount(annual_tuition)} #{currency}"
  end

  # Check if this band covers a specific grade
  def covers_grade?(grade)
    grade >= grade_from && grade <= grade_to
  end

  private

  def grade_to_greater_than_from
    return unless grade_from && grade_to

    if grade_to < grade_from
      errors.add(:grade_to, "must be greater than or equal to grade from")
    end
  end

  def no_overlapping_bands
    return unless grade_from && grade_to && school_fee_schedule_id

    overlapping = self.class.joins(:school_fee_schedule)
                      .where(school_fee_schedule: school_fee_schedule)
                      .where.not(id: id)
                      .where("(grade_from <= ? AND grade_to >= ?) OR (grade_from <= ? AND grade_to >= ?)",
                             grade_from, grade_from, grade_to, grade_to)

    if overlapping.exists?
      errors.add(:base, "Grade range overlaps with existing fee band")
    end
  end

  def formatted_amount(amount)
    amount.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
