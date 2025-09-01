# SchoolsController manages the main school listing with distance-based filtering
# Supports AJAX requests for real-time filtering without page reloads
class SchoolsController < ApplicationController
  before_action :check_home_location, only: [:index]
  before_action :set_puppeteer_location_in_session
  before_action :find_school, only: [:show]

  def show
    # Eager load all related data to avoid N+1 queries
    # @school is already set by find_school before_action, just reload with includes
    @school = School.includes(
      :place,
      :current_taggings,
      :current_terms,
      :school_fee_schedules,
      :school_grade_offering,
      :media_items,
      current_taggings: { term: :vocabulary },
      place: :media_items
    ).find(@school.id)
    
    # Find related point data if available
    @related_point = find_related_point(@school) if @school.place
    
    # Initialize data merger for intelligent data combination
    @merged_data = SchoolDataMerger.new(@school, @school.place, @related_point).merged_data
    
    # Set page metadata
    @page_title = @school.name
    @page_description = @merged_data.additional_details[:about] || 
                       "Learn about #{@school.name} - curriculum, facilities, fees, and more."
    @page_keywords = generate_page_keywords(@school)
  end

  def index
    # For HTML requests, the location controller will handle redirects to onboarding
    # For JSON/AJAX requests, we need location parameters
    @home_location = get_home_location_from_client
    
    if request.format.json? && !@home_location
      render json: { error: "Home location required" }, status: :bad_request
      return
    end
    
    if @home_location
      @filter_params = filter_params
      @schools = filtered_schools
      @total_count = School.published.count
      @filtered_count = @schools.total_count
    else
      # For HTML requests without location, set defaults that will be overridden by JavaScript
      @home_location = { lat: 13.7563, lng: 100.5018 } # Bangkok center as default
      @filter_params = { radius: 50, show_all: false, page: 1 }
      @schools = Kaminari.paginate_array([]).page(1).per(25)
      @total_count = School.published.count
      @filtered_count = 0
    end

    respond_to do |format|
      format.html
      format.json { render json: schools_json_response }
    end
  end

  def filtered
    @home_location = get_home_location_from_client
    
    unless @home_location
      render json: { error: "Home location required" }, status: :bad_request
      return
    end

    @filter_params = filter_params
    @schools = filtered_schools
    @total_count = School.published.count
    @filtered_count = @schools.total_count

    render json: schools_json_response
  end

  def search
    @home_location = get_home_location_from_client
    
    unless @home_location
      render json: { error: "Home location required" }, status: :bad_request
      return
    end

    query = params[:q]&.strip
    
    unless query.present?
      render json: { schools: [] }
      return
    end

    # Search all published schools by name (no distance limit)
    @schools = School.published
                    .joins(:place)
                    .where("schools.name ILIKE ?", "%#{query}%")
                    .select(search_select_fields)
                    .limit(20) # Limit to 20 results for dropdown

    # Calculate distance for each school and sort by distance
    schools_with_distance = @schools.map do |school|
      distance = School.calculate_haversine_distance(
        @home_location[:lat], 
        @home_location[:lng], 
        school.place_lat, 
        school.place_lng
      )
      
      {
        id: school.id,
        name: school.name,
        slug: school.slug,
        address: school.address,
        distance_km: distance.round(1),
        url: school_path(school)
      }
    end.sort_by { |school| school[:distance_km] }

    render json: { schools: schools_with_distance }
  end

  private

  def filter_params
    params.permit(:radius, :show_all, :page).tap do |p|
      p[:radius] = (p[:radius]&.to_i || 50).clamp(1, 100)
      p[:show_all] = p[:show_all] == 'true'
      p[:page] = [p[:page].to_i, 1].max
    end
  end

  def filtered_schools
    if @filter_params[:show_all]
      # Show all published schools, paginated
      School.published
            .joins(:place)
            .select(school_select_fields)
            .order(:name)
            .page(@filter_params[:page])
            .per(25)
    else
      # Filter by distance and calculate distance
      School.with_distance(@home_location[:lat], @home_location[:lng], @filter_params[:radius])
            .page(@filter_params[:page])
            .per(25)
    end
  end

  def school_select_fields
    if @filter_params[:show_all]
      'schools.id, schools.name, schools.slug, places.formatted_address as address, NULL as distance_km'
    else
      'schools.id, schools.name, schools.slug, places.formatted_address as address, 
       ST_Distance(ST_SetSRID(ST_MakePoint(places.lng, places.lat), 4326), ST_SetSRID(ST_MakePoint(?, ?), 4326)) / 1000.0 as distance_km'
    end
  end

  def search_select_fields
    'schools.id, schools.name, schools.slug, places.formatted_address as address, places.lat as place_lat, places.lng as place_lng'
  end

  def schools_json_response
    {
      schools: @schools.map do |school|
        {
          id: school.id,
          name: school.name,
          slug: school.slug,
          address: school.address,
          distance_km: @filter_params[:show_all] ? nil : school.distance_km&.round(1),
          url: school_path(school)
        }
      end,
      pagination: {
        current_page: @schools.current_page,
        total_pages: @schools.total_pages,
        per_page: @schools.limit_value,
        total_count: @filtered_count,
        has_next: @schools.current_page < @schools.total_pages,
        has_prev: @schools.current_page > 1
      },
      meta: {
        total_schools: @total_count,
        filtered_count: @filtered_count,
        showing_all: @filter_params[:show_all],
        radius_km: @filter_params[:radius],
        home_location: {
          lat: @home_location[:lat],
          lng: @home_location[:lng]
        }
      }
    }
  end

  def get_home_location_from_client
    # Check for Puppeteer backdoor first
    puppeteer_location = get_location_with_backdoor
    return puppeteer_location if puppeteer_location

    # Client sends coordinates via JavaScript
    if params[:home_lat].present? && params[:home_lng].present?
      lat = params[:home_lat].to_f
      lng = params[:home_lng].to_f
      
      # Basic validation
      return nil unless valid_coordinates?(lat, lng)
      
      { lat: lat, lng: lng }
    end
  end

  def valid_coordinates?(lat, lng)
    lat.between?(-90, 90) && lng.between?(-180, 180)
  end

  def check_home_location
    # Skip location check for Puppeteer requests
    return if puppeteer_request?
    
    # This will be handled by the location Stimulus controller
    # which redirects to onboarding if no home location exists
  end

  def find_school
    # Handle both slug and numeric ID formats
    if params[:id].match?(/\A\d+\z/)
      @school = School.find(params[:id])
    else
      @school = School.find_by!(slug: params[:id])
    end
  end
  
  # Find related point data by proximity
  def find_related_point(school)
    return nil unless school.place&.lat && school.place&.lng
    
    # Find the closest point within 500 meters, handling SRID mismatches
    Point.where(
      "ST_DWithin(ST_Transform(way, 4326), ST_SetSRID(ST_MakePoint(?, ?), 4326), ?)",
      school.place.lng,
      school.place.lat,
      500
    ).first
  rescue ActiveRecord::StatementInvalid => e
    # If there's still an SRID issue, log and return nil
    Rails.logger.warn "PostGIS SRID error when finding related point: #{e.message}"
    nil
  end
  
  # Generate SEO keywords from school data
  def generate_page_keywords(school)
    keywords = [school.name]
    keywords << school.district if school.district.present?
    keywords << school.province if school.province.present?
    
    # Add curriculum keywords from taxonomy
    curricula = school.current_terms.select { |term| term.vocabulary.code == 'curriculum' }
    curricula.each { |curriculum| keywords << curriculum.label }
    
    # Add common education keywords
    keywords += %w[school education bangkok thailand international curriculum]
    
    keywords.uniq.join(', ')
  end
end