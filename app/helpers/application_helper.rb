module ApplicationHelper
  # Format currency for Thai Baht
  def format_currency(amount, currency = "THB")
    return nil if amount.blank?

    formatted = number_with_delimiter(amount.to_i, delimiter: ",")
    case currency.upcase
    when "THB"
      "#{formatted} ฿"
    when "USD"
      "$#{formatted}"
    else
      "#{formatted} #{currency}"
    end
  end

  # Format phone number for display
  def format_phone(phone)
    return nil if phone.blank?

    # Simple Thai phone number formatting
    cleaned = phone.gsub(/\D/, "")

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
    when "phone"
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, d: "M2 3a1 1 0 011-1h2.153a1 1 0 01.986.836l.74 4.435a1 1 0 01-.54 1.06l-1.548.773a11.037 11.037 0 006.105 6.105l.774-1.548a1 1 0 011.059-.54l4.435.74a1 1 0 01.836.986V17a1 1 0 01-1 1h-2C7.82 18 2 12.18 2 5V3z"
      end
    when "envelope", "email"
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        concat content_tag(:path, nil, d: "M2.003 5.884L10 9.882l7.997-3.998A2 2 0 0016 4H4a2 2 0 00-1.997 1.884z")
        concat content_tag(:path, nil, d: "M18 8.118l-8 4-8-4V14a2 2 0 002 2h12a2 2 0 002-2V8.118z")
      end
    when "globe", "website"
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, fill_rule: "evenodd", d: "M4.083 9h1.946c.089-1.546.383-2.97.837-4.118A6.004 6.004 0 004.083 9zM10 2a8 8 0 100 16 8 8 0 000-16zm0 2c-.076 0-.232.032-.465.262-.238.234-.497.623-.737 1.182-.389.907-.673 2.142-.766 3.556h3.936c-.093-1.414-.377-2.649-.766-3.556-.24-.56-.5-.948-.737-1.182C10.232 4.032 10.076 4 10 4zm3.971 5c-.089-1.546-.383-2.97-.837-4.118A6.004 6.004 0 0115.917 9h-1.946zm-2.003 2H8.032c.093 1.414.377 2.649.766 3.556.24.56.5.948.737 1.182.233.23.389.262.465.262.076 0 .232-.032.465-.262.238-.234.498-.623.737-1.182.389-.907.673-2.142.766-3.556zm1.166 4.118c.454-1.147.748-2.572.837-4.118h1.946a6.004 6.004 0 01-2.783 4.118zm-6.268 0C6.412 13.97 6.118 12.546 6.03 11H4.083a6.004 6.004 0 002.783 4.118z", clip_rule: "evenodd"
      end
    when "map-pin", "location"
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, fill_rule: "evenodd", d: "M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z", clip_rule: "evenodd"
      end
    when "star"
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, d: "M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"
      end
    when "academic-cap"
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, d: "M10.394 2.08a1 1 0 00-.788 0l-7 3a1 1 0 000 1.84L5.25 8.051a.999.999 0 01.356-.257l4-1.714a1 1 0 11.788 1.838L7.667 9.088l1.94.831a1 1 0 00.787 0l7-3a1 1 0 000-1.838l-7-3zM3.31 9.397L5 10.12v4.102a8.969 8.969 0 00-1.05-.174 1 1 0 01-.89-.89 11.115 11.115 0 01.25-3.762zM9.3 16.573A9.026 9.026 0 007 14.935v-3.957l1.818.78a3 3 0 002.364 0l5.508-2.361a11.026 11.026 0 01.25 3.762 1 1 0 01-.89.89 8.968 8.968 0 00-5.35 2.524 1 1 0 01-1.4 0zM6 18a1 1 0 001-1v-2.065a8.935 8.935 0 00-2-.712V17a1 1 0 001 1z"
      end
    when "currency-dollar"
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, d: "M8.433 7.418c.155-.103.346-.196.567-.267v1.698a2.305 2.305 0 01-.567-.267C8.07 8.34 8 8.114 8 8c0-.114.07-.34.433-.582zM11 12.849v-1.698c.22.071.412.164.567.267.364.243.433.468.433.582 0 .114-.07.34-.433.582a2.305 2.305 0 01-.567.267z"
      end
    when "building-office"
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, fill_rule: "evenodd", d: "M4 16.5v-13h-.25a.75.75 0 010-1.5h12.5a.75.75 0 010 1.5H16v13h.25a.75.75 0 010 1.5H3.75a.75.75 0 010-1.5H4zm1.25-11.25a.5.5 0 00-.5.5v.5c0 .28.22.5.5.5h1.5a.5.5 0 00.5-.5v-.5a.5.5 0 00-.5-.5h-1.5zm0 3a.5.5 0 00-.5.5v.5c0 .28.22.5.5.5h1.5a.5.5 0 00.5-.5v-.5a.5.5 0 00-.5-.5h-1.5zm0 3a.5.5 0 00-.5.5v.5c0 .28.22.5.5.5h1.5a.5.5 0 00.5-.5v-.5a.5.5 0 00-.5-.5h-1.5zm5-6a.5.5 0 00-.5.5v.5c0 .28.22.5.5.5h1.5a.5.5 0 00.5-.5v-.5a.5.5 0 00-.5-.5h-1.5zm0 3a.5.5 0 00-.5.5v.5c0 .28.22.5.5.5h1.5a.5.5 0 00.5-.5v-.5a.5.5 0 00-.5-.5h-1.5zm0 3a.5.5 0 00-.5.5v.5c0 .28.22.5.5.5h1.5a.5.5 0 00.5-.5v-.5a.5.5 0 00-.5-.5h-1.5z", clip_rule: "evenodd"
      end
    when "chat-bubble-left"
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, fill_rule: "evenodd", d: "M2 10c0-3.967 3.69-7 8-7s8 3.033 8 7-3.69 7-8 7a8.097 8.097 0 01-1.75-.2A4.5 4.5 0 015 18.16v-2.26A6.985 6.985 0 012 10z", clip_rule: "evenodd"
      end
    when "information-circle"
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, fill_rule: "evenodd", d: "M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a.75.75 0 000 1.5h.253a.25.25 0 01.244.304l-.459 2.066A1.75 1.75 0 0010.747 15H11a.75.75 0 000-1.5h-.253a.25.25 0 01-.244-.304l.459-2.066A1.75 1.75 0 009.253 9H9z", clip_rule: "evenodd"
      end
    when "check-circle"
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, fill_rule: "evenodd", d: "M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.236 4.53L8.093 10.5a.75.75 0 00-1.186.918l1.914 2.478a.75.75 0 001.199-.094l3.857-5.4z", clip_rule: "evenodd"
      end
    when "x-circle"
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, fill_rule: "evenodd", d: "M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z", clip_rule: "evenodd"
      end
    when "trophy"
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, fill_rule: "evenodd", d: "M5 2a1 1 0 011 1v1.1a4.002 4.002 0 003.2 6.2 8.001 8.001 0 0015.8 0 1 1 0 11-.8-.6A6.002 6.002 0 0114 5.1V3a1 1 0 011-1h1a3 3 0 013 3v.93a1.5 1.5 0 01-.44 1.06l-3 3a1.5 1.5 0 01-1.06.44H13v1.5a6.5 6.5 0 01-13 0V11H.5a1.5 1.5 0 01-1.06-.44l-3-3A1.5 1.5 0 01-4 6.5V5a3 3 0 013-3h1zm5 16.25A4.75 4.75 0 0014.75 13.5V12h-9.5v1.5A4.75 4.75 0 0010 18.25z", clip_rule: "evenodd"
      end
    when "cake"
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, d: "M6 3a1 1 0 011-1h6a1 1 0 011 1v1.586l1.707 1.707A1 1 0 0115 7v4a1 1 0 01-1 1h-1v3a1 1 0 01-1 1H8a1 1 0 01-1-1v-3H6a1 1 0 01-1-1V7a1 1 0 01.293-.707L7 4.586V3zM8 5.414L6.586 6.828A1 1 0 016 7.414V10h8V7.414a1 1 0 01-.414-.586L12 5.414V4H8v1.414z"
      end
    when "heart"
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, fill_rule: "evenodd", d: "M3.172 5.172a4 4 0 015.656 0L10 6.343l1.172-1.171a4 4 0 115.656 5.656L10 17.657l-6.828-6.829a4 4 0 010-5.656z", clip_rule: "evenodd"
      end
    when "computer-desktop"
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, fill_rule: "evenodd", d: "M2 4.25A2.25 2.25 0 014.25 2h11.5A2.25 2.25 0 0118 4.25v8.5A2.25 2.25 0 0115.75 15H4.25A2.25 2.25 0 012 12.75v-8.5zm2 7.25v1a.75.75 0 00.75.75h10.5a.75.75 0 00.75-.75v-1H4zm0-1.5h12V4.25a.75.75 0 00-.75-.75H4.75a.75.75 0 00-.75.75v5.75z", clip_rule: "evenodd"
      end
    when "musical-note"
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, d: "M18 3a1 1 0 00-1.196-.98l-10 2A1 1 0 006 5v9.114A4.369 4.369 0 005 14c-1.657 0-3 .895-3 2s1.343 2 3 2 3-.895 3-2V7.82l8-1.6v5.894A4.369 4.369 0 0015 12c-1.657 0-3 .895-3 2s1.343 2 3 2 3-.895 3-2V3z"
      end
    when "squares-plus"
      content_tag :svg, class: icon_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, nil, fill_rule: "evenodd", d: "M1 5.25A2.25 2.25 0 013.25 3h4.5A2.25 2.25 0 0110 5.25v4.5A2.25 2.25 0 017.75 12h-4.5A2.25 2.25 0 011 9.75v-4.5zm9 0A2.25 2.25 0 0112.25 3h4.5A2.25 2.25 0 0119 5.25v4.5A2.25 2.25 0 0116.75 12h-4.5A2.25 2.25 0 0110 9.75v-4.5zM1 14.25A2.25 2.25 0 013.25 12h4.5A2.25 2.25 0 0110 14.25v2.5A2.25 2.25 0 017.75 19h-4.5A2.25 2.25 0 011 16.75v-2.5zM12.25 12A2.25 2.25 0 0110 14.25v2.5A2.25 2.25 0 0112.25 19H14v1.25a.75.75 0 001.5 0V19h1.25a.75.75 0 000-1.5H15.5v-1.25a.75.75 0 00-1.5 0v1.25h-1.25z", clip_rule: "evenodd"
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
    ENV["DEBUG_MODE"].to_s.downcase == "on"
  end
end
