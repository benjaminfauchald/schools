module ApplicationHelper
  # Format currency for Thai Baht
  def format_currency(amount, currency = 'THB')
    return nil if amount.blank?
    
    formatted = number_with_delimiter(amount.to_i, delimiter: ',')
    case currency.upcase
    when 'THB'
      "#{formatted} ฿"
    when 'USD'
      "$#{formatted}"
    else
      "#{formatted} #{currency}"
    end
  end
  
  # Format phone number for display
  def format_phone(phone)
    return nil if phone.blank?
    
    # Simple Thai phone number formatting
    cleaned = phone.gsub(/\D/, '')
    
    case cleaned.length
    when 10
      # Thai mobile: 08X-XXX-XXXX
      "#{cleaned[0..2]}-#{cleaned[3..5]}-#{cleaned[6..9]}"
    when 9
      # Thai landline: 0X-XXX-XXXX  
      "#{cleaned[0..1]}-#{cleaned[2..4]}-#{cleaned[5..8]}"
    else
      phone # Return original if we can't format it
    end
  end
  
  # Get Heroicon SVG
  def heroicon(name, type: :outline, css_class: nil)
    icon_class = css_class || "w-5 h-5"
    
    case name.to_s
    when 'phone'
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, d: "M2 3a1 1 0 011-1h2.153a1 1 0 01.986.836l.74 4.435a1 1 0 01-.54 1.06l-1.548.773a11.037 11.037 0 006.105 6.105l.774-1.548a1 1 0 011.059-.54l4.435.74a1 1 0 01.836.986V17a1 1 0 01-1 1h-2C7.82 18 2 12.18 2 5V3z"
      end
    when 'envelope', 'email'
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        concat content_tag(:path, nil, d: "M2.003 5.884L10 9.882l7.997-3.998A2 2 0 0016 4H4a2 2 0 00-1.997 1.884z")
        concat content_tag(:path, nil, d: "M18 8.118l-8 4-8-4V14a2 2 0 002 2h12a2 2 0 002-2V8.118z")
      end
    when 'globe', 'website'
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, fill_rule: "evenodd", d: "M4.083 9h1.946c.089-1.546.383-2.97.837-4.118A6.004 6.004 0 004.083 9zM10 2a8 8 0 100 16 8 8 0 000-16zm0 2c-.076 0-.232.032-.465.262-.238.234-.497.623-.737 1.182-.389.907-.673 2.142-.766 3.556h3.936c-.093-1.414-.377-2.649-.766-3.556-.24-.56-.5-.948-.737-1.182C10.232 4.032 10.076 4 10 4zm3.971 5c-.089-1.546-.383-2.97-.837-4.118A6.004 6.004 0 0115.917 9h-1.946zm-2.003 2H8.032c.093 1.414.377 2.649.766 3.556.24.56.5.948.737 1.182.233.23.389.262.465.262.076 0 .232-.032.465-.262.238-.234.498-.623.737-1.182.389-.907.673-2.142.766-3.556zm1.166 4.118c.454-1.147.748-2.572.837-4.118h1.946a6.004 6.004 0 01-2.783 4.118zm-6.268 0C6.412 13.97 6.118 12.546 6.03 11H4.083a6.004 6.004 0 002.783 4.118z", clip_rule: "evenodd"
      end
    when 'map-pin', 'location'
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, fill_rule: "evenodd", d: "M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z", clip_rule: "evenodd"
      end
    when 'star'
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, d: "M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"
      end
    when 'academic-cap'
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, d: "M10.394 2.08a1 1 0 00-.788 0l-7 3a1 1 0 000 1.84L5.25 8.051a.999.999 0 01.356-.257l4-1.714a1 1 0 11.788 1.838L7.667 9.088l1.94.831a1 1 0 00.787 0l7-3a1 1 0 000-1.838l-7-3zM3.31 9.397L5 10.12v4.102a8.969 8.969 0 00-1.05-.174 1 1 0 01-.89-.89 11.115 11.115 0 01.25-3.762zM9.3 16.573A9.026 9.026 0 007 14.935v-3.957l1.818.78a3 3 0 002.364 0l5.508-2.361a11.026 11.026 0 01.25 3.762 1 1 0 01-.89.89 8.968 8.968 0 00-5.35 2.524 1 1 0 01-1.4 0zM6 18a1 1 0 001-1v-2.065a8.935 8.935 0 00-2-.712V17a1 1 0 001 1z"
      end
    when 'currency-dollar'
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, d: "M8.433 7.418c.155-.103.346-.196.567-.267v1.698a2.305 2.305 0 01-.567-.267C8.07 8.34 8 8.114 8 8c0-.114.07-.34.433-.582zM11 12.849v-1.698c.22.071.412.164.567.267.364.243.433.468.433.582 0 .114-.07.34-.433.582a2.305 2.305 0 01-.567.267z"
      end
    when 'building-office'
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, fill_rule: "evenodd", d: "M4 16.5v-13h-.25a.75.75 0 010-1.5h12.5a.75.75 0 010 1.5H16v13h.25a.75.75 0 010 1.5H3.75a.75.75 0 010-1.5H4zm1.25-11.25a.5.5 0 00-.5.5v.5c0 .28.22.5.5.5h1.5a.5.5 0 00.5-.5v-.5a.5.5 0 00-.5-.5h-1.5zm0 3a.5.5 0 00-.5.5v.5c0 .28.22.5.5.5h1.5a.5.5 0 00.5-.5v-.5a.5.5 0 00-.5-.5h-1.5zm0 3a.5.5 0 00-.5.5v.5c0 .28.22.5.5.5h1.5a.5.5 0 00.5-.5v-.5a.5.5 0 00-.5-.5h-1.5zm5-6a.5.5 0 00-.5.5v.5c0 .28.22.5.5.5h1.5a.5.5 0 00.5-.5v-.5a.5.5 0 00-.5-.5h-1.5zm0 3a.5.5 0 00-.5.5v.5c0 .28.22.5.5.5h1.5a.5.5 0 00.5-.5v-.5a.5.5 0 00-.5-.5h-1.5zm0 3a.5.5 0 00-.5.5v.5c0 .28.22.5.5.5h1.5a.5.5 0 00.5-.5v-.5a.5.5 0 00-.5-.5h-1.5z", clip_rule: "evenodd"
      end
    else
      # Default icon if name not found
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, fill_rule: "evenodd", d: "M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z", clip_rule: "evenodd"
      end
    end
  end
  
  # Document status badge classes
  def document_status_badge_classes(document)
    case document.processing_status
    when :completed
      "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800"
    when :failed
      "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800"
    when :processing
      "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800"
    when :pending
      "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-yellow-100 text-yellow-800"
    else
      "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800"
    end
  end
  
  # Generate meta tags for SEO
  def school_meta_tags(school, merged_data)
    title = school.name
    description = merged_data.additional_details[:about] || "Learn about #{school.name} - curriculum, facilities, fees, and more."
    
    content_for :meta_tags do
      concat tag(:meta, name: "description", content: description)
      concat tag(:meta, property: "og:title", content: title)
      concat tag(:meta, property: "og:description", content: description)
      concat tag(:meta, property: "og:type", content: "place")
      
      if merged_data.contact_info[:coordinates]
        lat, lng = merged_data.contact_info[:coordinates]
        concat tag(:meta, property: "place:location:latitude", content: lat)
        concat tag(:meta, property: "place:location:longitude", content: lng)
      end
    end
  end
  
  # Check if debug mode is enabled
  def debug_mode_enabled?
    ENV['DEBUG_MODE'].to_s.downcase == 'on'
  end
end
