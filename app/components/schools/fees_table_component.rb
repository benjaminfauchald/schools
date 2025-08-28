# frozen_string_literal: true

class Schools::FeesTableComponent < ViewComponent::Base
  def initialize(fee_schedules:, fee_bands:)
    @fee_schedules = fee_schedules
    @fee_bands = fee_bands
  end

  private

  attr_reader :fee_schedules, :fee_bands

  def render?
    fee_schedules.any? || fee_bands.any?
  end

  def organized_fees
    @organized_fees ||= build_organized_fees
  end

  def build_organized_fees
    fees = {}
    
    # Add detailed fee schedules first
    fee_schedules.each do |schedule|
      grade_key = schedule.grade_level || 'General'
      fees[grade_key] ||= {
        grade: grade_key,
        items: [],
        total_range: nil
      }
      
      fees[grade_key][:items] << {
        type: 'Fee Schedule',
        description: schedule.fee_type || 'Tuition',
        amount: schedule.amount,
        currency: schedule.currency || 'THB',
        frequency: schedule.frequency || 'Annual',
        notes: schedule.notes
      }
    end

    # Add fee band ranges
    fee_bands.each do |band|
      grade_key = band.grade_level || 'General'
      fees[grade_key] ||= {
        grade: grade_key,
        items: [],
        total_range: nil
      }
      
      fees[grade_key][:total_range] = {
        min: band.min_amount,
        max: band.max_amount,
        currency: band.currency || 'THB',
        frequency: band.frequency || 'Annual'
      }
    end

    fees.values.sort_by { |f| grade_sort_order(f[:grade]) }
  end

  def grade_sort_order(grade)
    case grade.to_s.downcase
    when /pre|nursery|kindergarten/ then 1
    when /primary|elementary/ then 2
    when /secondary|middle|high/ then 3
    when /general/ then 99
    else 50
    end
  end

  def has_detailed_fees?
    fee_schedules.any?
  end

  def has_fee_ranges?
    fee_bands.any?
  end

  def fee_range_summary
    return nil unless fee_bands.any?
    
    all_mins = fee_bands.map(&:min_amount).compact
    all_maxs = fee_bands.map(&:max_amount).compact
    
    return nil if all_mins.empty? && all_maxs.empty?
    
    {
      min: all_mins.min,
      max: all_maxs.max,
      currency: fee_bands.first&.currency || 'THB'
    }
  end

  def format_fee_amount(amount, currency = 'THB')
    return 'Contact school' if amount.blank?
    helpers.format_currency(amount, currency)
  end

  def format_fee_range(min_amount, max_amount, currency = 'THB')
    if min_amount && max_amount
      "#{format_fee_amount(min_amount, currency)} - #{format_fee_amount(max_amount, currency)}"
    elsif min_amount
      "From #{format_fee_amount(min_amount, currency)}"
    elsif max_amount
      "Up to #{format_fee_amount(max_amount, currency)}"
    else
      'Contact school for pricing'
    end
  end

  def frequency_badge_class(frequency)
    case frequency&.downcase
    when /annual|year/
      'bg-blue-100 text-blue-800 dark:bg-blue-900/50 dark:text-blue-300'
    when /semester|term/
      'bg-green-100 text-green-800 dark:bg-green-900/50 dark:text-green-300'
    when /month/
      'bg-purple-100 text-purple-800 dark:bg-purple-900/50 dark:text-purple-300'
    else
      'bg-gray-100 text-gray-800 dark:bg-gray-900/50 dark:text-gray-300'
    end
  end

  def section_icon_svg(icon_name)
    helpers.heroicon(icon_name, css_class: "w-5 h-5 text-gray-500 dark:text-gray-400")
  end
end