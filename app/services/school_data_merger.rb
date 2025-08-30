# SchoolDataMerger service class for intelligent data merging across School, Place, and Point models
# Implements priority-based data selection: School > Place > Point
# Filters out null/empty values and prevents data duplication
class SchoolDataMerger
  attr_reader :school, :place, :point
  
  def initialize(school, place = nil, point = nil)
    @school = school
    @place = place || school.place
    @point = point
  end
  
  # Main method to get all merged data for the school
  def merged_data
    @merged_data ||= OpenStruct.new(
      hero_data: hero_data,
      contact_info: contact_info,
      location_data: location_data,
      academic_programs: academic_programs,
      facilities: facilities,
      fees: fees,
      grade_offerings: grade_offerings,
      operational_details: operational_details,
      media_items: media_items,
      media_items_array: media_items_array,
      additional_details: additional_details
    )
  end
  
  # Hero section data (name, photo, key stats)
  def hero_data
    {
      name: prioritized_value(school.name, place&.name, point&.name),
      logo: primary_logo,
      hero_image: primary_hero_image,
      rating: rating_data,
      grade_range: grade_range_display,
      fee_range: fee_range_display,
      key_stats: key_statistics
    }
  end
  
  # Contact information with priority merging
  def contact_info
    {
      phone: display_phone,
      email: display_email,
      website: display_website,
      facebook_url: school.facebook_url,
      line_id: school.line_id,
      whatsapp_number: school.whatsapp_number,
      address: display_address,
      coordinates: coordinates,
      google_maps_url: maps_url
    }.compact
  end
  
  # Location and address data
  def location_data
    {
      formatted_address: display_address,
      district: prioritized_value(school.district, extract_district_from_place),
      province: prioritized_value(school.province, extract_province_from_place),
      country: school.country_code || 'TH',
      coordinates: coordinates,
      vicinity: place&.vicinity
    }.compact
  end
  
  # Academic programs from taxonomy
  def academic_programs
    {
      curricula: terms_by_vocabulary('curriculum'),
      accreditations: terms_by_vocabulary('accreditation'),
      languages: terms_by_vocabulary('language'),
      programs: terms_by_vocabulary('program')
    }.reject { |_, v| v.empty? }
  end
  
  # Facilities from taxonomy
  def facilities
    terms_by_vocabulary('facility')
  end
  
  # Fee information
  def fees
    return {} unless school.school_fee_schedules.any?
    
    current_schedule = school.school_fee_schedules.first
    
    {
      current_schedule: current_schedule,
      academic_year: current_schedule.academic_year,
      currency: current_schedule.currency,
      tuition_range: fee_range_display,
      additional_fees: {
        application: current_schedule.application_fee,
        enrollment: current_schedule.enrollment_fee,
        capital_levy: current_schedule.capital_levy,
        boarding: current_schedule.boarding_fee_annual,
        transport: current_schedule.transport_fee_annual
      }.compact
    }
  end
  
  # Grade offerings and age ranges
  def grade_offerings
    offering = school.school_grade_offering
    return {} unless offering
    
    {
      age_range: offering.age_range_display,
      grades: offering.grades_display,
      educational_level: offering.educational_level,
      min_age: offering.min_age,
      max_age: offering.max_age,
      serves_early_years: offering.serves_early_years?,
      serves_elementary: offering.serves_elementary?,
      serves_secondary: offering.serves_secondary?
    }.compact
  end
  
  # Operational details and characteristics
  def operational_details
    {
      founded_year: school.founded_year,
      ownership: school.ownership&.humanize,
      boarding_available: school.boarding?,
      school_bus_available: school.school_bus?,
      student_teacher_ratio: school.student_teacher_ratio,
      avg_class_size: school.avg_class_size,
      status: school.status,
      about: prioritized_value(school.about, place&.editorial_summary),
      business_hours: place&.opening_hours,
      business_status: place&.business_status
    }.compact
  end
  
  # Media items (photos, logos) - prioritize Google Places photos over test data
  def media_items
    items = []
    
    # Add Google Places photos first (these are real photos), but only visible ones
    if place&.photos.present?
      visible_photos = place.photos.select { |photo| school.photo_visible?(photo) }
      google_photos = visible_photos.map.with_index do |photo, index|
        OpenStruct.new(
          kind: 'photo',
          url: google_places_photo_url(photo['photo_reference']),
          alt_text: "#{school.name} - Photo #{index + 1}",
          sort_order: index,
          created_at: place.updated_at || Time.current
        )
      end
      items.concat(google_photos)
    end
    
    # Only add MediaItem data if it's not test data
    media_items_data = (school.media_items.to_a + (place&.media_items&.to_a || []))
      .reject { |item| item.url.blank? || item.alt_text&.include?('TEST_DATA') }
    
    items.concat(media_items_data)
    
    # Sort by kind (logos first) then by sort_order
    items = items.sort_by { |item| [item.kind == 'logo' ? 0 : 1, item.sort_order || 999, item.created_at || Time.current] }
    
    {
      all: items,
      logos: items.select { |item| item.kind == 'logo' },
      photos: items.select { |item| item.kind == 'photo' },
      primary_logo: items.find { |item| item.kind == 'logo' },
      hero_image: items.find { |item| item.kind == 'photo' }
    }
  end
  
  # Media items array for photo gallery component compatibility
  def media_items_array
    media_items[:all]
  end
  
  # Generate Google Places photo URL from photo reference
  def google_places_photo_url(photo_reference, max_width: 800)
    # Use Rails credentials or environment variable for Google API key
    api_key = Rails.application.credentials.google_places_api_key || ENV['GOOGLE_PLACES_API_KEY']
    
    if api_key.present?
      "https://maps.googleapis.com/maps/api/place/photo?photoreference=#{photo_reference}&maxwidth=#{max_width}&key=#{api_key}"
    else
      # Fallback to a placeholder if no API key
      "https://via.placeholder.com/#{max_width}x600/4ECDC4/FFFFFF?text=Photo+Not+Available"
    end
  end
  
  # Additional details that don't fit other categories
  def additional_details
    {
      last_updated: [school.updated_at, place&.updated_at].compact.max,
      verified: school.last_verification_at.present?,
      place_rating: place&.rating,
      user_ratings_total: place&.user_ratings_total,
      price_level: place&.price_level,
      wheelchair_accessible: place&.wheelchair_accessible_entrance
    }.compact
  end
  
  private
  
  # Return first non-blank value from sources in priority order
  def prioritized_value(*sources)
    sources.find { |value| value.present? }
  end
  
  # Display phone with formatting
  def display_phone
    phone = prioritized_value(
      school.phone,
      place&.formatted_phone_number,
      place&.international_phone_number,
      point&.phone
    )
    
    return nil if phone.blank?
    format_phone_number(phone)
  end
  
  # Display email
  def display_email
    prioritized_value(school.email, point&.email)
  end
  
  # Display website URL
  def display_website
    website = prioritized_value(school.website_url, place&.website, point&.website)
    return nil if website.blank?
    
    # Ensure URL has protocol
    website.start_with?('http') ? website : "https://#{website}"
  end
  
  # Display formatted address
  def display_address
    prioritized_value(
      school.formatted_address,
      place&.formatted_address,
      build_point_address
    )
  end
  
  # Get coordinates for mapping
  def coordinates
    lat = prioritized_value(school.lat, place&.lat, point&.lat)
    lng = prioritized_value(school.lng, place&.lng, point&.lon)
    
    return nil unless lat && lng
    [lat.to_f, lng.to_f]
  end
  
  # Get Google Maps URL
  def maps_url
    coords = coordinates
    return place&.google_maps_url if coords.blank?
    
    place&.google_maps_url || "https://www.google.com/maps?q=#{coords[0]},#{coords[1]}"
  end
  
  # Primary logo for hero section
  def primary_logo
    media_items[:primary_logo]
  end
  
  # Primary hero image
  def primary_hero_image
    media_items[:hero_image]
  end
  
  # Rating data with source attribution
  def rating_data
    rating = place&.rating
    return nil unless rating
    
    {
      rating: rating.to_f,
      total_ratings: place&.user_ratings_total,
      source: 'Google',
      stars_display: ('★' * rating.to_i) + ('☆' * (5 - rating.to_i))
    }
  end
  
  # Grade range display for hero section
  def grade_range_display
    return nil unless school.school_grade_offering
    
    offering = school.school_grade_offering
    return offering.grades if offering.grades.present?
    
    # Fallback to age range if grades not available
    if offering.min_age && offering.max_age
      "Ages #{offering.min_age.to_i}-#{offering.max_age.to_i}"
    end
  end

  # Fee range display for hero section
  def fee_range_display
    return nil unless school.school_fee_schedules.any?
    
    schedule = school.school_fee_schedules.first
    return nil unless schedule.min_tuition || schedule.max_tuition
    
    currency = schedule.currency || 'THB'
    if schedule.min_tuition && schedule.max_tuition
      min_formatted = format_currency(schedule.min_tuition, currency)
      max_formatted = format_currency(schedule.max_tuition, currency)
      "#{min_formatted} - #{max_formatted}"
    elsif schedule.min_tuition
      "From #{format_currency(schedule.min_tuition, currency)}"
    elsif schedule.max_tuition
      "Up to #{format_currency(schedule.max_tuition, currency)}"
    end
  end

  private

  # Helper to get terms by vocabulary code
  def terms_by_vocabulary(vocab_code)
    school.current_terms.select { |term| term.vocabulary.code == vocab_code }
  end

  def format_currency(amount, currency)
    formatted = amount.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    case currency.upcase
    when 'THB'
      "#{formatted} ฿"
    when 'USD'
      "$#{formatted}"
    else
      "#{formatted} #{currency}"
    end
  end

  # Key statistics for hero display
  def key_statistics
    stats = []
    
    if school.school_grade_offering
      offering = school.school_grade_offering
      if offering.min_age && offering.max_age
        stats << {
          icon: 'academic-cap',
          label: 'Ages',
          value: "#{offering.min_age.to_i}-#{offering.max_age.to_i}"
        }
      end
    end
    
    if school.school_fee_schedules.any?
      fee_display = fee_range_display
      if fee_display
        stats << {
          icon: 'currency-dollar',
          label: 'Fees',
          value: fee_display
        }
      end
    end
    
    if rating_data
      stats << {
        icon: 'star',
        label: 'Rating',
        value: "#{rating_data[:rating]} (#{rating_data[:total_ratings]} reviews)"
      }
    end
    
    facilities_count = facilities.count
    if facilities_count > 0
      stats << {
        icon: 'building-office',
        label: 'Facilities',
        value: "#{facilities_count} facilities"
      }
    end
    
    stats
  end
  
  # Extract district from place address components
  def extract_district_from_place
    return nil unless place&.address_components
    
    district_component = place.address_components.find do |c|
      c['types'].include?('sublocality_level_1') || c['types'].include?('administrative_area_level_2')
    end
    district_component&.dig('long_name')
  end
  
  # Extract province from place address components
  def extract_province_from_place
    return nil unless place&.address_components
    
    province_component = place.address_components.find { |c| c['types'].include?('administrative_area_level_1') }
    province_component&.dig('long_name')
  end
  
  # Build address from point data
  def build_point_address
    return nil unless point
    
    components = [
      point.addr_housenumber,
      point.addr_street,
      point.addr_district,
      point.addr_subdistrict,
      point.addr_city,
      point.addr_province,
      point.addr_postcode
    ].compact
    
    components.any? ? components.join(', ') : point.address
  end
  
  # Format phone number for display
  def format_phone_number(phone)
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
end