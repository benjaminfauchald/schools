# School model represents educational institutions with rich metadata and taxonomy support
# Integrates with Place for location data and supports comprehensive filtering and search
class School < ApplicationRecord
  belongs_to :place, optional: true
  
  # Active Storage attachments
  has_many_attached :photos
  
  # School-specific associations
  has_one :school_grade_offering, dependent: :destroy
  has_many :school_fee_schedules, dependent: :destroy
  has_many :school_claims, dependent: :destroy
  has_many :school_inquiries, dependent: :destroy
  has_many :pages, dependent: :destroy
  
  # Generic place associations (shared with other place types)
  has_many :media_items, through: :place
  has_many :events, through: :place
  has_many :travel_times, through: :place
  has_many :audit_logs, as: :auditable, dependent: :destroy
  
  # Taxonomy associations
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :terms, through: :taggings
  has_many :current_taggings, -> { valid_at }, class_name: 'Tagging', as: :taggable
  has_many :current_terms, through: :current_taggings, source: :term
  
  # Delegate location attributes to Place (single source of truth)
  delegate :formatted_address, :vicinity, :rating, :user_ratings_total, :formatted_phone_number,
           :international_phone_number, :website, :url, :opening_hours, :reviews,
           :google_maps_url, :coordinates, to: :place, prefix: false, allow_nil: true
  delegate :name, to: :place, prefix: :google, allow_nil: true
  
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :status, inclusion: { in: %w[draft pending_review published suspended] }
  validates :ownership, inclusion: { in: %w[nonprofit private foundation other] }, allow_blank: true
  validates :country_code, inclusion: { in: %w[TH US GB SG MY JP KR CN] }, allow_blank: true
  
  enum :status, {
    draft: 'draft',
    pending_review: 'pending_review', 
    published: 'published',
    suspended: 'suspended'
  }
  
  enum :ownership, {
    nonprofit: 'nonprofit',
    private: 'private',
    foundation: 'foundation',
    other: 'other'
  }, prefix: true
  
  before_validation :generate_slug, if: -> { name.present? && slug.blank? }
  after_update :sync_geography_from_coordinates, if: :saved_change_to_lat_or_lng?
  after_update :sync_coordinates_from_place, if: :saved_change_to_place_id?
  
  # Get contact info with Place fallback
  def display_phone
    phone.presence || formatted_phone_number
  end
  
  def display_website
    website_url.presence || website
  end
  
  def display_address
    if address_line_1.present?
      [address_line_1, address_line_2, district, province, postcode].compact.join(', ')
    else
      formatted_address
    end
  end
  
  # Taxonomy helpers
  def terms_by_context(context)
    current_terms.joins(:vocabulary).where(vocabularies: { code: context })
  end
  
  def curricula
    terms_by_context('curriculum')
  end
  
  def accreditations  
    terms_by_context('accreditation')
  end
  
  def facilities
    terms_by_context('facility')
  end
  
  def extracurriculars
    terms_by_context('extracurricular')
  end
  
  def languages
    terms_by_context('language')
  end
  
  def programs
    terms_by_context('program')
  end
  
  # Add terms to school
  def add_term(term, notes: nil, valid_from: nil, valid_to: nil)
    taggings.create!(
      term: term,
      context: term.vocabulary.code,
      notes: notes,
      valid_from: valid_from,
      valid_to: valid_to
    )
  end
  
  # Remove term from school
  def remove_term(term)
    taggings.where(term: term).destroy_all
  end
  
  # Check if school has specific term
  def has_term?(term_or_slug, context: nil)
    scope = current_taggings.joins(:term)
    
    if term_or_slug.is_a?(Term)
      scope = scope.where(term: term_or_slug)
    else
      scope = scope.where(terms: { slug: term_or_slug.to_s })
      scope = scope.joins(term: :vocabulary).where(vocabularies: { code: context }) if context
    end
    
    scope.exists?
  end
  
  # Get curriculum slugs (for API compatibility)
  def curriculum_slugs
    curricula.pluck(:slug)
  end
  
  def accreditation_slugs
    accreditations.pluck(:slug)
  end
  
  def facility_slugs
    facilities.pluck(:slug)
  end
  
  # Fee helpers
  def current_fee_schedule
    school_fee_schedules.published.order(academic_year: :desc).first
  end
  
  def tuition_range
    current_fee_schedule&.tuition_range_display
  end
  
  # Grade offering helpers
  def age_range
    school_grade_offering&.age_range_display || 'Ages not specified'
  end
  
  def grade_levels
    school_grade_offering&.grades_display || 'Grades not specified'
  end
  
  def educational_level
    school_grade_offering&.educational_level || 'Level not specified'
  end
  
  # Check if school has any claims (approved or pending)
  def claimed?
    school_claims.exists?
  end
  
  # Check if school has approved claims
  def approved_claims?
    school_claims.where(status: 'approved').exists?
  end
  
  # Photo visibility management methods
  def visible_google_photos
    return [] unless place&.photos&.present?
    
    place.photos.select { |photo| photo_visible?(photo) }
  end
  
  def photo_visible?(photo)
    return true unless photo_visibility_settings.present?
    
    photo_key = generate_photo_key(photo)
    photo_visibility_settings.fetch(photo_key, true) # Default to visible
  end
  
  def set_photo_visibility(photo, visible)
    photo_key = generate_photo_key(photo)
    self.photo_visibility_settings = (photo_visibility_settings || {}).merge(photo_key => visible)
  end
  
  def toggle_photo_visibility(photo)
    current_visibility = photo_visible?(photo)
    set_photo_visibility(photo, !current_visibility)
    !current_visibility
  end
  
  # Generate a unique key for each Google Places photo
  def generate_photo_key(photo)
    if photo.is_a?(Hash)
      photo['photo_reference'] || photo.to_s.hash.to_s
    elsif photo.respond_to?(:photo_reference)
      photo.photo_reference
    else
      photo.to_s.hash.to_s
    end
  end
  
  private
  
  def sync_geography_from_coordinates
    update_geography! if lat.present? && lng.present?
  end
  
  def sync_coordinates_from_place
    sync_from_place! if place
  end
  
  def saved_change_to_lat_or_lng?
    saved_change_to_lat? || saved_change_to_lng?
  end
  
  scope :published, -> { where(status: 'published') }
  scope :by_district, ->(district) { where(district: district) }
  scope :by_province, ->(province) { where(province: province) }
  scope :with_boarding, -> { where(boarding: true) }
  scope :with_school_bus, -> { where(school_bus: true) }
  
  # Distance-based filtering scope for main school listing
  # Using Haversine formula for distance calculation - simpler and more reliable
  scope :with_distance, ->(lat, lng, radius_km = 50) do
    return none unless lat.present? && lng.present?
    
    # Calculate distance using Haversine formula in Ruby
    schools_with_distance = joins(:place)
                           .where(status: 'published')
                           .select('schools.id, schools.name, schools.slug, places.formatted_address as address, places.lat as place_lat, places.lng as place_lng')
                           .map do |school|
      distance = calculate_haversine_distance(lat, lng, school.place_lat, school.place_lng)
      next if distance > radius_km
      
      # Add distance as a virtual attribute
      school.define_singleton_method(:distance_km) { distance }
      school.define_singleton_method(:address) { school.read_attribute(:address) }
      school
    end.compact.sort_by(&:distance_km)
    
    # Return as a relation-like object that supports pagination
    Kaminari.paginate_array(schools_with_distance)
  end
  
  # Helper method for Haversine distance calculation
  def self.calculate_haversine_distance(lat1, lng1, lat2, lng2)
    return 0.0 if lat1 == lat2 && lng1 == lng2
    
    rad_per_deg = Math::PI / 180
    rkm = 6371  # Earth radius in kilometers
    
    dlat_rad = (lat2 - lat1) * rad_per_deg
    dlon_rad = (lng2 - lng1) * rad_per_deg
    
    lat1_rad = lat1 * rad_per_deg
    lat2_rad = lat2 * rad_per_deg
    
    a = Math.sin(dlat_rad/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad/2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
    
    rkm * c
  end
  
  def self.search_by_name(query)
    return all if query.blank?
    
    where("name ILIKE ? OR tsv @@ plainto_tsquery(?)", "%#{query}%", query)
  end
  
  def self.near(lat, lng, distance_km = 10)
    return all unless lat.present? && lng.present?
    
    where("ST_DWithin(geog, ST_SetSRID(ST_MakePoint(?, ?), 4326), ?)", lng, lat, distance_km * 1000)
  end
  
  def update_geography!
    return unless lat.present? && lng.present?
    
    update_column(:geog, "SRID=4326;POINT(#{lng} #{lat})")
  end
  
  def distance_from(origin_lat, origin_lng)
    return place.distance_from(origin_lat, origin_lng) if place
    return nil unless lat.present? && lng.present?
    
    # Using PostGIS ST_Distance for geography calculations (returns meters)
    result = self.class.connection.select_value(
      "SELECT ST_Distance(geog, ST_SetSRID(ST_MakePoint(?, ?), 4326)) FROM schools WHERE id = ?",
      origin_lng, origin_lat, id
    )
    result&.to_f
  end
  
  def full_address
    return formatted_address if place&.formatted_address.present?
    [address_line_1, address_line_2, district, province, postcode].compact.join(', ')
  end
  
  # Sync location data from associated Place
  def sync_from_place!
    return unless place
    
    update!(
      lat: place.lat,
      lng: place.lng,
      address_line_1: extract_street_from_place,
      district: extract_district_from_place,
      province: extract_province_from_place,
      postcode: extract_postcode_from_place,
      phone: place.formatted_phone_number.presence || phone,
      website_url: place.website.presence || website_url
    )
    
    update_geography!
  end
  
  def verified?
    last_verification_at.present? && last_verification_at > 6.months.ago
  end
  
  # Facebook data helpers
  def has_facebook_data?
    facebook_content.present?
  end
  
  def facebook_logo_url
    facebook_profile_picture_url || facebook_content&.dig('visual_assets', 'profile_picture', 'url')
  end
  
  def facebook_hero_image_url
    facebook_cover_photo_url || facebook_content&.dig('visual_assets', 'cover_photo', 'url')
  end
  
  def facebook_data_age_in_days
    return nil unless facebook_last_fetched
    (Time.current - facebook_last_fetched) / 1.day
  end
  
  def needs_facebook_refresh?
    facebook_url.present? && (
      facebook_last_fetched.nil? || 
      facebook_data_age_in_days > 30
    )
  end
  
  private
  
  def generate_slug
    base_slug = name.parameterize
    counter = 1
    candidate_slug = base_slug
    
    while School.exists?(slug: candidate_slug)
      candidate_slug = "#{base_slug}-#{counter}"
      counter += 1
    end
    
    self.slug = candidate_slug
  end
  
  # Extract location components from Place address_components
  def extract_street_from_place
    return nil unless place&.address_components
    
    street_component = place.address_components.find { |c| c['types'].include?('route') }
    street_number = place.address_components.find { |c| c['types'].include?('street_number') }
    
    [street_number&.dig('long_name'), street_component&.dig('long_name')].compact.join(' ')
  end
  
  def extract_district_from_place
    return nil unless place&.address_components
    
    district_component = place.address_components.find do |c| 
      c['types'].include?('sublocality_level_1') || c['types'].include?('administrative_area_level_2')
    end
    district_component&.dig('long_name')
  end
  
  def extract_province_from_place
    return nil unless place&.address_components
    
    province_component = place.address_components.find { |c| c['types'].include?('administrative_area_level_1') }
    province_component&.dig('long_name')
  end
  
  def extract_postcode_from_place
    return nil unless place&.address_components
    
    postal_component = place.address_components.find { |c| c['types'].include?('postal_code') }
    postal_component&.dig('long_name')
  end
end