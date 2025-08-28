# frozen_string_literal: true

class Schools::SectionHeaderComponent < ViewComponent::Base
  def initialize(title:, icon: nil, subtitle: nil, actions: nil)
    @title = title
    @icon = icon
    @subtitle = subtitle
    @actions = actions
  end

  private

  attr_reader :title, :icon, :subtitle, :actions

  def icon_svg
    return unless icon
    helpers.heroicon(icon, css_class: "w-5 h-5 text-gray-500 dark:text-gray-400")
  end

  def has_content?
    content.present? || subtitle.present? || actions.present?
  end
end