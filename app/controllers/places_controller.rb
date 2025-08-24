class PlacesController < ApplicationController
  before_action :find_place, only: [:show]

  def show
    @place = @place_record
    @distance = calculate_distance_from_home if home_location_available?
  end

  private

  def find_place
    @place_record = Place.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Place not found."
  end

  def home_location_available?
    params[:home_lat].present? && params[:home_lng].present?
  end

  def calculate_distance_from_home
    return nil unless home_location_available?

    home_lat = params[:home_lat].to_f
    home_lng = params[:home_lng].to_f
    
    calculate_distance(home_lat, home_lng, @place_record.lat, @place_record.lng)
  end
end