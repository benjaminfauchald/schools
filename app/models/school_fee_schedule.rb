# SchoolFeeSchedule model manages tuition and fees for specific academic years
# Supports versioned fee structures with one-time and recurring fees
class SchoolFeeSchedule < ApplicationRecord
  belongs_to :school
  has_many :school_fee_bands, dependent: :destroy
  
  validates :academic_year, presence: true, uniqueness: { scope: :school_id }
  validates :currency, presence: true
  validates :min_tuition, :max_tuition, numericality: { greater_than: 0 }, allow_nil: true
  validates :application_fee, :enrollment_fee, :capital_levy, :boarding_fee_annual, 
            :transport_fee_annual, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  validate :max_tuition_greater_than_min
  
  scope :published, -> { where(is_published: true) }
  scope :current_academic_year, -> { 
    current_year = Date.current.year
    where("academic_year LIKE ? OR academic_year LIKE ?", "#{current_year}%", "%#{current_year}")
  }
  scope :by_academic_year, ->(year) { where(academic_year: year) }
  
  # Get tuition range as formatted string
  def tuition_range_display
    return nil unless min_tuition && max_tuition
    
    if min_tuition == max_tuition
      "#{formatted_amount(min_tuition)} #{currency}"
    else
      "#{formatted_amount(min_tuition)} - #{formatted_amount(max_tuition)} #{currency}"
    end
  end
  
  # Check if this is the current academic year
  def current_year?
    current_year = Date.current.year
    academic_year.include?(current_year.to_s)
  end
  
  # Get all one-time fees
  def one_time_fees
    {
      application_fee: application_fee,
      enrollment_fee: enrollment_fee,
      capital_levy: capital_levy
    }.compact
  end
  
  # Get all annual fees  
  def annual_fees
    {
      boarding_fee_annual: boarding_fee_annual,
      transport_fee_annual: transport_fee_annual
    }.compact
  end
  
  private
  
  def max_tuition_greater_than_min
    return unless min_tuition && max_tuition
    
    if max_tuition < min_tuition
      errors.add(:max_tuition, 'must be greater than or equal to minimum tuition')
    end
  end
  
  def formatted_amount(amount)
    number_with_delimiter(amount.to_i)
  end
  
  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end