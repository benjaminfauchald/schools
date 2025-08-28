# frozen_string_literal: true

class Schools::TagBadgeComponent < ViewComponent::Base
  def initialize(term:, variant: :default, size: :base)
    @term = term
    @variant = variant
    @size = size
  end

  private

  attr_reader :term, :variant, :size

  def css_classes
    base_classes = "inline-flex items-center font-medium rounded-full"
    
    # Size variants
    size_classes = case size
    when :sm
      "px-2 py-0.5 text-xs"
    when :base
      "px-2.5 py-0.5 text-sm"
    when :lg
      "px-3 py-1 text-base"
    end
    
    # Color variants based on vocabulary context
    color_classes = case variant
    when :curriculum
      "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300"
    when :accreditation
      "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300"
    when :facility
      "bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-300"
    when :extracurricular
      "bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-300"
    when :language
      "bg-pink-100 text-pink-800 dark:bg-pink-900 dark:text-pink-300"
    when :program
      "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300"
    else # default
      "bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300"
    end
    
    "#{base_classes} #{size_classes} #{color_classes}"
  end
  
  def term_label
    term.label
  end
end