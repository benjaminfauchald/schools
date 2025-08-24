# Place model stores location data from Google Maps API for any type of establishment
# Serves as the single source of truth for location, contact, and business information
class Place < ApplicationRecord
  belongs_to :point, optional: true
  has_one :school, dependent: :destroy
  has_many :media_items, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :travel_times, dependent: :destroy
  
  # Validations
  validates :place_id, presence: true, uniqueness: true
  validates :lat, :lng, presence: true, numericality: true
  
  # Scopes
  scope :with_ratings, -> { where.not(rating: nil) }
  scope :highly_rated, -> { where('rating >= ?', 4.0) }
  scope :open_now, -> { where("opening_hours->>'open_now' = 'true'") }
  scope :schools, -> { where("'school' = ANY(ARRAY(SELECT json_array_elements_text(types)))") }
  # Google Maps API compliance scopes (30-day cache limit)
  scope :recently_fetched, -> { where('last_fetched_at > ?', 1.day.ago) }
  scope :needs_refresh, -> { where('last_fetched_at IS NULL OR last_fetched_at < ?', 30.days.ago) }
  scope :google_maps_compliant, -> { where('last_fetched_at IS NULL OR last_fetched_at >= ?', 30.days.ago) }
  scope :google_maps_expired, -> { where('last_fetched_at < ?', 30.days.ago) }
  scope :successful_fetches, -> { where(api_status: 'OK') }
  scope :failed_fetches, -> { where.not(api_status: 'OK') }
  
  # Website crawling scopes
  scope :with_websites, -> { where.not(website: [nil, '']) }
  scope :needs_web_crawling, -> { where(website_crawled_at: nil).or(where('website_crawled_at < ?', 30.days.ago)).or(where(website_crawling_status: 'failed')) }
  scope :web_scraping_expired, -> { where('website_crawled_at < ?', 30.days.ago) }
  scope :recently_crawled, -> { where('website_crawled_at > ?', 7.days.ago) }
  scope :successfully_crawled, -> { where(website_crawling_status: 'completed') }
  scope :failed_crawls, -> { where(website_crawling_status: 'failed') }
  scope :crawling_in_progress, -> { where(website_crawling_status: 'crawling') }
  scope :with_structured_data, -> { where.not(website_structured_data: [nil, {}]) }
  
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
    last_fetched_at.nil? || last_fetched_at < 30.days.ago
  end

  def google_maps_compliant?
    last_fetched_at.nil? || last_fetched_at >= 30.days.ago
  end

  def days_since_last_fetch
    return nil if last_fetched_at.nil?
    (Time.current - last_fetched_at) / 1.day
  end
  
  # Website crawling methods
  def needs_web_scraping?
    return false if website.blank?
    website_crawled_at.nil? || website_crawled_at < 30.days.ago || website_crawling_status == 'failed'
  end
  
  def has_structured_data?
    website_structured_data.present? && !website_structured_data.empty?
  end
  
  def web_crawl_successful?
    website_crawling_status == 'completed' && website_crawled_at.present?
  end
  
  def days_since_last_crawl
    return nil if website_crawled_at.nil?
    (Time.current - website_crawled_at) / 1.day
  end
  
  def website_crawl_status_display
    case website_crawling_status
    when 'completed' then "✅ Completed (#{website_pages_found || 0} pages)"
    when 'failed' then "❌ Failed: #{website_crawling_error&.truncate(50)}"
    when 'crawling' then "🔄 In Progress"
    else "⏳ Pending"
    end
  end
  
  def structured_data_summary
    return "No data" unless has_structured_data?
    
    sections = website_structured_data.keys.count { |k| !k.start_with?('_') && website_structured_data[k].present? }
    "#{sections} sections with data"
  end
  
  # Distance calculation using PostGIS
  def distance_from(origin_lat, origin_lng)
    return nil unless lat.present? && lng.present?
    
    # Using PostGIS ST_Distance for geography calculations (returns meters)
    result = self.class.connection.select_value(
      "SELECT ST_Distance(ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography)",
      lng, lat, origin_lng, origin_lat
    )
    result&.to_f
  end
  
  # Class method to check Google Maps API compliance percentage
  def self.google_maps_compliance_percentage
    total = count
    return 0 if total == 0
    
    compliant = google_maps_compliant.count
    (compliant.to_f / total * 100).round(1)
  end
  
  # Class method to check website crawling statistics
  def self.website_crawling_stats
    total_with_websites = with_websites.count
    return { total: 0, crawled: 0, success_rate: 0, pages_avg: 0 } if total_with_websites == 0
    
    crawled = with_websites.where.not(website_crawled_at: nil).count
    successful = with_websites.successfully_crawled.count
    failed = with_websites.failed_crawls.count
    avg_pages = with_websites.where.not(website_pages_found: nil).average(:website_pages_found)&.round(1) || 0
    
    {
      total_with_websites: total_with_websites,
      crawled: crawled,
      successful: successful,
      failed: failed,
      success_rate: total_with_websites > 0 ? (successful.to_f / total_with_websites * 100).round(1) : 0,
      pages_avg: avg_pages,
      needs_crawling: with_websites.needs_web_crawling.count
    }
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
