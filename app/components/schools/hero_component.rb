# frozen_string_literal: true

class Schools::HeroComponent < ViewComponent::Base
  def initialize(hero_data:, contact_info:)
    @hero_data = hero_data
    @contact_info = contact_info
  end

  private

  attr_reader :hero_data, :contact_info

  def school_name
    hero_data[:name]
  end

  def hero_image_url
    hero_data[:hero_image]&.url || hero_data[:logo]&.url
  end

  def rating_display
    return unless hero_data[:rating]
    
    rating = hero_data[:rating]
    {
      stars: rating[:stars_display],
      value: rating[:rating],
      count: rating[:total_ratings],
      source: rating[:source]
    }
  end

  def key_stats
    hero_data[:key_stats] || []
  end

  def contact_actions
    actions = []
    
    if contact_info[:phone]
      actions << {
        label: 'Call',
        icon: 'phone',
        url: "tel:#{contact_info[:phone].gsub(/\D/, '')}",
        primary: true
      }
    end
    
    if contact_info[:email]
      actions << {
        label: 'Email',
        icon: 'envelope',
        url: "mailto:#{contact_info[:email]}",
        primary: false
      }
    end
    
    if contact_info[:website]
      actions << {
        label: 'Website',
        icon: 'globe',
        url: contact_info[:website],
        primary: false,
        external: true
      }
    end
    
    if contact_info[:google_maps_url]
      actions << {
        label: 'Directions',
        icon: 'map-pin',
        url: contact_info[:google_maps_url],
        primary: false,
        external: true
      }
    end
    
    actions
  end

  def stat_icon_svg(icon_name)
    helpers.heroicon(icon_name, css_class: "w-5 h-5 text-blue-600")
  end

  def action_button_classes(primary: false)
    base = "inline-flex items-center px-4 py-2 border text-sm font-medium rounded-md transition-colors duration-200"
    
    if primary
      "#{base} border-transparent text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
    else
      "#{base} border-gray-300 text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 dark:bg-gray-800 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
    end
  end

  def action_icon_svg(icon_name)
    helpers.heroicon(icon_name, css_class: "w-4 h-4 mr-2")
  end
end