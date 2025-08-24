class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  def index
    @places = Place.successful_fetches.with_ratings.limit(100)
    @first_place = @places.first
  end

  
end
