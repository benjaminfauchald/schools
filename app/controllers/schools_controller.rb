# SchoolsController manages the main school listing with distance-based filtering
# Supports AJAX requests for real-time filtering without page reloads
class SchoolsController < ApplicationController
  before_action :check_home_location, only: [:index]
  before_action :find_school, only: [:show]

  def show
    # School details page
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
    # This will be handled by the location Stimulus controller
    # which redirects to onboarding if no home location exists
  end

  def find_school
    @school = School.find_by!(slug: params[:id])
  end
end