class Place < ApplicationRecord
  belongs_to :point, optional: true
  
  # Validations
  validates :place_id, presence: true, uniqueness: true
  validates :lat, :lng, presence: true, numericality: true
  
  # Scopes
  scope :with_ratings, -> { where.not(rating: nil) }
  scope :highly_rated, -> { where('rating >= ?', 4.0) }
  scope :open_now, -> { where("opening_hours->>'open_now' = 'true'") }
  scope :schools, -> { where("'school' = ANY(ARRAY(SELECT json_array_elements_text(types)))") }
  scope :recently_fetched, -> { where('last_fetched_at > ?', 1.day.ago) }
  scope :needs_refresh, -> { where('last_fetched_at IS NULL OR last_fetched_at < ?', 1.week.ago) }
  scope :successful_fetches, -> { where(api_status: 'OK') }
  scope :failed_fetches, -> { where.not(api_status: 'OK') }
  
  # Class methods for API data processing
  def self.create_from_google_api(api_response, point = nil)
    place_data = extract_place_data(api_response)
    place_data[:point] = point if point
    place_data[:raw_api_response] = api_response
    place_data[:last_fetched_at] = Time.current
    place_data[:api_status] = api_response['status'] || 'OK'
    
    create!(place_data)
  end
  
  def self.update_from_google_api(place_id, api_response, point = nil)
    place = find_by(place_id: place_id)
    return create_from_google_api(api_response, point) unless place
    
    place_data = extract_place_data(api_response)
    place_data[:point] = point if point
    place_data[:raw_api_response] = api_response
    place_data[:last_fetched_at] = Time.current
    place_data[:api_status] = api_response['status'] || 'OK'
    
    place.update!(place_data)
    place
  end
  
  # Instance methods
  def google_maps_url
    url.presence || "https://www.google.com/maps/place/?q=place_id:#{place_id}"
  end
  
  def has_photos?
    photos.present? && photos.any?
  end
  
  def has_reviews?
    reviews.present? && reviews.any?
  end
  
  def open_now?
    opening_hours&.dig('open_now') == true
  end
  
  def coordinates
    [lat, lng]
  end
  
  def rating_stars
    return 'No rating' unless rating
    ('★' * rating.to_i) + ('☆' * (5 - rating.to_i))
  end
  
  def primary_type
    types&.first
  end
  
  def is_school?
    types&.include?('school') || types&.include?('university')
  end
  
  def needs_refresh?
    last_fetched_at.nil? || last_fetched_at < 1.week.ago
  end
  
  def phone_display
    formatted_phone_number.presence || international_phone_number
  end
  
  private
  
  def self.extract_place_data(api_response)
    result = api_response['result'] || api_response
    
    {
      place_id: result['place_id'],
      google_place_id: result['id'],
      name: result['name'],
      formatted_address: result['formatted_address'],
      vicinity: result['vicinity'],
      business_status: result['business_status'],
      rating: result['rating']&.to_f,
      user_ratings_total: result['user_ratings_total'],
      price_level: result['price_level'],
      lat: result.dig('geometry', 'location', 'lat')&.to_f,
      lng: result.dig('geometry', 'location', 'lng')&.to_f,
      formatted_phone_number: result['formatted_phone_number'],
      international_phone_number: result['international_phone_number'],
      website: result['website'],
      url: result['url'],
      opening_hours: result['opening_hours'],
      current_opening_hours: result['current_opening_hours'],
      secondary_opening_hours: result['secondary_opening_hours'],
      types: result['types'],
      icon: result['icon'],
      icon_background_color: result['icon_background_color'],
      icon_mask_base_uri: result['icon_mask_base_uri'],
      address_components: result['address_components'],
      plus_code_compound_code: result.dig('plus_code', 'compound_code'),
      plus_code_global_code: result.dig('plus_code', 'global_code'),
      reviews: result['reviews'],
      photos: result['photos'],
      editorial_summary: result.dig('editorial_summary', 'overview'),
      geometry_data: result['geometry'],
      permanently_closed: result['permanently_closed'],
      reference: result['reference'],
      scope: result['scope'],
      utc_offset: result['utc_offset'],
      wheelchair_accessible_entrance: result['wheelchair_accessible_entrance']
    }
  end
end
