# frozen_string_literal: true

class Schools::GradeOfferingsComponent < ViewComponent::Base
  def initialize(grade_offerings:)
    @grade_offerings = Array(grade_offerings).compact
  end

  private

  attr_reader :grade_offerings

  def render?
    grade_offerings.any?
  end

  def organized_grades
    @organized_grades ||= build_organized_grades
  end

  def build_organized_grades
    return [] if grade_offerings.empty?
    
    grade_offerings.map do |offering|
      {
        system: 'Grade Levels',
        levels: parse_grades_string(offering.grades),
        age_range: { min: offering.min_age, max: offering.max_age },
        total_years: count_grades_in_string(offering.grades),
        notes: offering.notes
      }
    end
  end

  # Parse grades string like "Nursery/Pre-K, Kindergarten, Grades 1-6, Grade 7"
  def parse_grades_string(grades_str)
    return [] if grades_str.blank?
    
    grades_str.split(',').map(&:strip).map do |grade|
      {
        grade: grade,
        min_age: nil,
        max_age: nil,
        description: nil,
        capacity: nil
      }
    end
  end

  # Count approximate number of grade levels in string
  def count_grades_in_string(grades_str)
    return 0 if grades_str.blank?
    
    # Simple heuristic: count commas + 1, but expand ranges like "Grades 1-6"
    expanded = grades_str.gsub(/Grades? (\d+)-(\d+)/) do |match|
      start_grade = $1.to_i
      end_grade = $2.to_i
      (start_grade..end_grade).to_a.join(', Grade ')
    end
    
    expanded.split(',').count
  end

  def system_sort_order(system)
    case system
    when 'Early Years' then 1
    when 'Primary Education' then 2
    when 'Secondary Education' then 3
    when 'International Baccalaureate' then 4
    when 'British Curriculum' then 5
    when 'American Curriculum' then 6
    else 99
    end
  end

  def grade_sort_order(grade)
    grade_str = grade.to_s.downcase
    
    # Extract numeric value for sorting
    if grade_str.match(/(\d+)/)
      $1.to_i
    elsif grade_str.include?('nursery')
      0
    elsif grade_str.include?('pre')
      1
    elsif grade_str.include?('kindergarten') || grade_str.include?('reception')
      2
    else
      999
    end
  end

  def format_age_range(min_age, max_age)
    if min_age && max_age
      min_int = min_age.to_i
      max_int = max_age.to_i
      if min_int == max_int
        "#{min_int} years old"
      else
        "#{min_int}-#{max_int} years old"
      end
    elsif min_age
      "#{min_age.to_i}+ years old"
    elsif max_age
      "up to #{max_age.to_i} years old"
    else
      "Contact school for age requirements"
    end
  end

  def system_icon(system)
    case system
    when 'Early Years' then 'heart'
    when 'Primary Education' then 'academic-cap'
    when 'Secondary Education' then 'building-library'
    when 'International Baccalaureate' then 'globe'
    when 'British Curriculum' then 'flag'
    when 'American Curriculum' then 'star'
    else 'squares-plus'
    end
  end

  def system_color(system)
    case system
    when 'Early Years' then 'pink'
    when 'Primary Education' then 'blue'
    when 'Secondary Education' then 'green'
    when 'International Baccalaureate' then 'purple'
    when 'British Curriculum' then 'red'
    when 'American Curriculum' then 'indigo'
    else 'gray'
    end
  end

  def total_grade_levels
    grade_offerings.count
  end

  def age_range_summary
    all_mins = grade_offerings.map(&:min_age).compact
    all_maxs = grade_offerings.map(&:max_age).compact
    
    return nil if all_mins.empty? && all_maxs.empty?
    
    {
      min: all_mins.min,
      max: all_maxs.max
    }
  end

  def section_icon_svg(icon_name)
    helpers.heroicon(icon_name, css_class: "w-5 h-5 text-gray-500 dark:text-gray-400")
  end

  def system_badge_class(color)
    case color
    when 'pink'
      'bg-pink-100 text-pink-800 dark:bg-pink-900/50 dark:text-pink-300'
    when 'blue'
      'bg-blue-100 text-blue-800 dark:bg-blue-900/50 dark:text-blue-300'
    when 'green'
      'bg-green-100 text-green-800 dark:bg-green-900/50 dark:text-green-300'
    when 'purple'
      'bg-purple-100 text-purple-800 dark:bg-purple-900/50 dark:text-purple-300'
    when 'red'
      'bg-red-100 text-red-800 dark:bg-red-900/50 dark:text-red-300'
    when 'indigo'
      'bg-indigo-100 text-indigo-800 dark:bg-indigo-900/50 dark:text-indigo-300'
    else
      'bg-gray-100 text-gray-800 dark:bg-gray-900/50 dark:text-gray-300'
    end
  end
end