# frozen_string_literal: true

class Schools::DataRowComponent < ViewComponent::Base
  def initialize(label:, value: nil, icon: nil, link: nil, format: nil)
    @label = label
    @value = value
    @icon = icon
    @link = link
    @format = format
  end

  private

  attr_reader :label, :value, :icon, :link, :format

  def render?
    value.present?
  end

  def formatted_value
    case format
    when :currency
      helpers.format_currency(value)
    when :phone
      helpers.format_phone(value)
    when :email
      value
    when :url
      display_url(value)
    when :social
      value
    else
      value
    end
  end

  def display_url(url)
    return url unless url.start_with?('http')
    
    begin
      uri = URI.parse(url)
      # Extract just the domain name, removing www if present
      domain = uri.host&.sub(/^www\./, '') || url
      domain
    rescue URI::InvalidURIError
      # Fallback to simple regex if URI parsing fails
      cleaned = url.gsub(%r{^https?://(www\.)?}, '')
      cleaned.split('/').first || cleaned
    end
  end

  def icon_svg
    return unless icon
    helpers.heroicon(icon, css_class: "w-4 h-4 text-gray-400 mr-3 flex-shrink-0")
  end

  def value_content
    if link.present?
      link_to formatted_value, link, 
              class: "text-blue-600 hover:text-blue-800",
              target: ([:url, :social].include?(format) ? '_blank' : nil),
              rel: ([:url, :social].include?(format) ? 'noopener noreferrer' : nil)
    else
      content_tag :span, formatted_value, 
                  class: "text-black"
    end
  end
end