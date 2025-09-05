class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Include Puppeteer location backdoor for testing
  include PuppeteerLocationBackdoor

  # Internationalization
  before_action :set_locale

  # Add helper methods for location calculations and authentication
  helper_method :calculate_distance, :format_distance, :facebook_authenticated, :debug_mode_enabled

  # Redirect users after sign in based on their role
  def after_sign_in_path_for(resource)
    if resource.is_a?(User) && resource.school_owner?
      school_owner_dashboard_index_path
    else
      stored_location_for(resource) || root_path
    end
  end

  def index
    @places = Place.successful_fetches.with_ratings.limit(100)
    @first_place = @places.first
  end
  
  def not_found
    render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
  end

  private

  # Calculate distance between two geographic points using Haversine formula
  # Returns distance in kilometers
  def calculate_distance(lat1, lon1, lat2, lon2)
    return nil if [lat1, lon1, lat2, lon2].any?(&:nil?)
    
    rad_per_deg = Math::PI / 180  # Pi / 180
    rkm = 6371                     # Earth radius in kilometers
    
    dlat_rad = (lat2 - lat1) * rad_per_deg  # Delta, converted to rad
    dlon_rad = (lon2 - lon1) * rad_per_deg
    
    lat1_rad = lat1 * rad_per_deg
    lat2_rad = lat2 * rad_per_deg
    
    a = Math.sin(dlat_rad/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad/2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
    
    rkm * c # Distance in km
  end

  # Format distance for display
  def format_distance(distance_km)
    return "Distance unknown" if distance_km.nil?
    
    if distance_km < 1
      "#{(distance_km * 1000).round} m"
    else
      "#{distance_km.round(1)} km"
    end
  end

  # Parse home location from client (for future server-side validation)
  def parse_home_location_from_params
    return nil unless params[:home_lat] && params[:home_lng]
    
    {
      lat: params[:home_lat].to_f,
      lng: params[:home_lng].to_f
    }
  end

  # Check if current user is authenticated with Facebook
  def facebook_authenticated
    user_signed_in? && current_user&.provider == 'facebook'
  end

  # Check if debug mode is enabled
  def debug_mode_enabled
    ENV['DEBUG_MODE'] == 'on'
  end

  # Set locale from params, session, or browser
  def set_locale
    I18n.locale = params[:locale] || session[:locale] || extract_locale_from_accept_language_header || I18n.default_locale
    session[:locale] = I18n.locale
  end

  private

  def extract_locale_from_accept_language_header
    return nil unless request.env['HTTP_ACCEPT_LANGUAGE']
    
    request.env['HTTP_ACCEPT_LANGUAGE']
           .scan(/^[a-z]{2}/)
           .map(&:to_sym)
           .find { |locale| I18n.available_locales.include?(locale) }
  end
end
