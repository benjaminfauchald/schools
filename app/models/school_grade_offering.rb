# SchoolGradeOffering model defines the age ranges and grade levels offered by a school
# Each school has one grade offering that specifies their educational coverage
class SchoolGradeOffering < ApplicationRecord
  belongs_to :school

  validates :school_id, uniqueness: true
  validates :min_age, :max_age, numericality: { greater_than: 0, less_than: 25 }, allow_nil: true
  validate :max_age_greater_than_min

  scope :early_years, -> { where("min_age < ?", 6) }
  scope :elementary, -> { where("min_age >= ? AND max_age <= ?", 5, 12) }
  scope :secondary, -> { where("min_age >= ? AND max_age >= ?", 10, 15) }
  scope :full_range, -> { where("min_age <= ? AND max_age >= ?", 6, 16) }

  # Get age range as display string
  def age_range_display
    return "Ages not specified" unless min_age && max_age

    if min_age == max_age
      "Age #{min_age.to_i}"
    else
      "Ages #{min_age.to_i}-#{max_age.to_i}"
    end
  end

  # Get grades as display string
  def grades_display
    return grades if grades.present?
    return "Grades not specified" unless min_age && max_age

    # Estimate grades from ages (rough approximation)
    min_grade = [ 0, min_age.to_i - 5 ].max
    max_grade = [ 12, max_age.to_i - 5 ].min

    if min_grade == max_grade
      "Grade #{min_grade}"
    else
      "Grades #{min_grade}-#{max_grade}"
    end
  end

  # Check if school serves early years (under 6)
  def serves_early_years?
    min_age.present? && min_age < 6
  end

  # Check if school serves elementary ages (5-12)
  def serves_elementary?
    return false unless min_age && max_age
    min_age <= 12 && max_age >= 5
  end

  # Check if school serves secondary ages (13+)
  def serves_secondary?
    return false unless max_age
    max_age >= 13
  end

  # Check if school covers a specific age
  def covers_age?(age)
    return false unless min_age && max_age
    age >= min_age && age <= max_age
  end

  # Get educational level based on age coverage
  def educational_level
    levels = []
    levels << "Early Years" if serves_early_years?
    levels << "Elementary" if serves_elementary?
    levels << "Secondary" if serves_secondary?
    levels.join(", ")
  end

  private

  def max_age_greater_than_min
    return unless min_age && max_age

    if max_age <= min_age
      errors.add(:max_age, "must be greater than minimum age")
    end
  end
end
