# SchoolsController manages the main school listing with distance-based filtering
# Supports AJAX requests for real-time filtering without page reloads
class SchoolsController < ApplicationController
  before_action :check_home_location, only: [:index]
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
        url: school_path(id: school.id)
      }
    end.sort_by { |school| school[:distance_km] }

    render json: { schools: schools_with_distance }
  end

  def ai_chat
    find_school
    
    message = params[:message]&.strip
    unless message.present?
      render json: { error: "Message is required" }, status: :bad_request
      return
    end
    
    begin
      # Create school context for AI
      school_context = build_school_context(@school)
      
      # Simple AI response (you can integrate with OpenAI or other AI services)
      response = generate_ai_response(message, school_context, @school)
      
      render json: { 
        response: response,
        school_name: @school.name 
      }
    rescue => e
      Rails.logger.error "AI Chat error: #{e.message}"
      render json: { 
        error: "Sorry, I'm having trouble processing your request right now. Please try again later." 
      }, status: :internal_server_error
    end
  end

  private

  def filter_params
    params.permit(:radius, :show_all, :page, :per_page).tap do |p|
      p[:radius] = (p[:radius]&.to_i || 50).clamp(1, 100)
      p[:show_all] = p[:show_all] == 'true'
      p[:page] = [p[:page].to_i, 1].max
      p[:per_page] = [p[:per_page]&.to_i || 25, 200].min.clamp(10, 200) # Allow 10-200 per page
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
            .per(@filter_params[:per_page])
    else
      # Filter by distance and calculate distance
      School.with_distance(@home_location[:lat], @home_location[:lng], @filter_params[:radius])
            .page(@filter_params[:page])
            .per(@filter_params[:per_page])
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
          url: school_path(id: school.id)
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
    # Simple Puppeteer coordinate injection - no complex backdoor needed!
    if puppeteer_request?
      Rails.logger.info "[SCHOOLS] 🤖 Puppeteer detected - injecting Bangkok coordinates"
      # Also set session data so JavaScript doesn't redirect to onboarding
      session[:puppeteer_location] = { lat: 13.6983415, lng: 100.5260653 }
      return { lat: 13.6983415, lng: 100.5260653 }
    end

    # Normal flow: Client sends coordinates via JavaScript
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

  def build_school_context(school)
    # Reload school with all associations for comprehensive data
    school_with_data = School.includes(
      :place,
      :current_taggings,
      :current_terms,
      :school_fee_schedules,
      :school_grade_offering,
      :media_items,
      current_taggings: { term: :vocabulary },
      place: :media_items
    ).find(school.id)
    
    merged_data = SchoolDataMerger.new(school_with_data, school_with_data.place, nil).merged_data
    
    context = {
      name: school.name,
      address: school_with_data.place&.formatted_address,
      curriculum: merged_data.academic_programs[:curricula]&.map(&:label),
      languages: merged_data.academic_programs[:languages]&.map(&:label),
      facilities: merged_data.facilities&.map(&:label),
      fee_schedules: merged_data.fee_schedules&.map do |fee|
        {
          grade_level: fee.grade_level,
          tuition_fee_thb: fee.tuition_fee_thb,
          registration_fee_thb: fee.registration_fee_thb
        }
      end,
      grade_offerings: school_with_data.school_grade_offering&.then do |offering|
        {
          min_age: offering.min_age,
          max_age: offering.max_age,
          grades: offering.grades_display
        }
      end
    }
    
    context.compact
  end

  def generate_ai_response(message, school_context, school)
    # This is a simple rule-based response system
    # You can replace this with OpenAI API integration
    
    message_lower = message.downcase
    school_name = school.name
    
    # Curriculum questions
    if message_lower.include?('curriculum') || message_lower.include?('program')
      curricula = school_context[:curriculum] || []
      if curricula.any?
        return "**Academic Programs at #{school_name}:**\n\n#{school_name} offers the following curriculum programs:\n\n#{curricula.map { |c| "• #{c}" }.join("\n")}\n\nEach program is designed to provide students with a comprehensive education that prepares them for higher education and future careers."
      else
        return "I don't have detailed curriculum information for #{school_name} at the moment. I'd recommend contacting the school directly for specific program details."
      end
    end
    
    # Fee questions
    if message_lower.include?('fee') || message_lower.include?('cost') || message_lower.include?('tuition') || message_lower.include?('price')
      fees = school_context[:fee_schedules] || []
      if fees.any?
        fee_info = fees.map do |fee|
          "• **#{fee[:grade_level]}**: ฿#{number_with_delimiter(fee[:tuition_fee_thb])} per year"
        end.join("\n")
        return "**Tuition Fees at #{school_name}:**\n\n#{fee_info}\n\n*Note: Fees may vary and additional costs for materials, activities, or services may apply. Please contact the school for the most current fee schedule.*"
      else
        return "I don't have specific fee information for #{school_name}. Please contact the school directly for detailed tuition and fee information."
      end
    end
    
    # Facilities questions
    if message_lower.include?('facilities') || message_lower.include?('facility')
      facilities = school_context[:facilities] || []
      if facilities.any?
        return "**Facilities at #{school_name}:**\n\n#{facilities.map { |f| "• #{f}" }.join("\n")}\n\nThese facilities support student learning and development across various subjects and activities."
      else
        return "I don't have detailed facilities information for #{school_name} at the moment. Please contact the school for more information about their campus facilities."
      end
    end
    
    # Language questions
    if message_lower.include?('language') || message_lower.include?('english') || message_lower.include?('thai')
      languages = school_context[:languages] || []
      if languages.any?
        return "**Languages at #{school_name}:**\n\n#{languages.map { |l| "• #{l}" }.join("\n")}\n\nThe school provides instruction and support in these languages to help students develop multilingual competencies."
      else
        return "I don't have specific language program information for #{school_name}. Please contact the school for details about their language instruction."
      end
    end
    
    # Age/grade questions
    if message_lower.include?('age') || message_lower.include?('grade') || message_lower.include?('level')
      grade_info = school_context[:grade_offerings]
      if grade_info
        return "**Grade Levels at #{school_name}:**\n\n• **Age Range**: #{grade_info[:min_age]} to #{grade_info[:max_age]} years old\n• **Grades**: #{grade_info[:grades]}\n\nThe school serves students across these age ranges with age-appropriate curriculum and activities."
      else
        return "I don't have specific grade level information for #{school_name}. Please contact the school for details about their age ranges and grade offerings."
      end
    end
    
    # Location questions
    if message_lower.include?('location') || message_lower.include?('address') || message_lower.include?('where')
      address = school_context[:address]
      if address
        return "**Location of #{school_name}:**\n\n📍 #{address}\n\nYou can find detailed directions and transportation options on our school page."
      else
        return "Please check the school's contact information section for location details."
      end
    end
    
    # General/default response
    return "**About #{school_name}:**\n\nI can help you learn more about #{school_name}! I can provide information about:\n\n• **Academic programs** and curriculum\n• **Tuition fees** and costs\n• **Facilities** and campus amenities\n• **Languages** of instruction\n• **Grade levels** and age ranges\n• **Location** and address\n\nWhat specific aspect of #{school_name} would you like to know more about?"
  end
end