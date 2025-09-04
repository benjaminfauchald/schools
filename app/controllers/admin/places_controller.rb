module Admin
  class PlacesController < Admin::ApplicationController

    def index
      search_term = params[:search]
      
      @places = Place.all
      
      # Apply search filter
      if search_term.present?
        @places = @places.where(
          "name ILIKE ? OR formatted_address ILIKE ? OR vicinity ILIKE ?", 
          "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
        )
      end
      
      # Apply business status filter
      if params[:business_status].present?
        @places = @places.where(business_status: params[:business_status])
      end
      
      # Apply API status filter
      if params[:api_status].present?
        @places = @places.where(api_status: params[:api_status])
      end
      
      # Apply rating filter
      if params[:rating_min].present?
        @places = @places.where("rating >= ?", params[:rating_min].to_f)
      end
      
      @places = @places.order(:name).limit(50)
      
      # Statistics
      @total_places = Place.count
      @places_with_rating = Place.where.not(rating: nil).count
      @operational_places = Place.where(business_status: 'OPERATIONAL').count
      @closed_places = Place.where(permanently_closed: true).count
      @places_with_photos = Place.where.not(photos: nil).count
      @avg_rating = Place.where.not(rating: nil).average(:rating)&.round(1)
    end

    def show
      @place = Place.includes(:point).find(params[:id])
      @has_google_data = @place.google_place_id.present?
      @has_coordinates = @place.lat.present? && @place.lng.present?
      @opening_hours = parse_opening_hours(@place.opening_hours) if @place.opening_hours.present?
      @photos = parse_photos(@place.photos) if @place.photos.present?
      @reviews = parse_reviews(@place.reviews) if @place.reviews.present?
    end

    def new
      @place = Place.new
    end

    def create
      @place = Place.new(place_params)
      
      if @place.save
        redirect_to admin_place_path(@place), notice: 'Place was successfully created.'
      else
        render :new
      end
    end

    def edit
      @place = Place.find(params[:id])
    end

    def update
      @place = Place.find(params[:id])
      
      if @place.update(place_params)
        redirect_to admin_place_path(@place), notice: 'Place was successfully updated.'
      else
        render :edit
      end
    end

    def destroy
      @place = Place.find(params[:id])
      
      if @place.point.present?
        redirect_to admin_places_path, alert: 'Cannot delete place with associated point data.'
      else
        @place.destroy
        redirect_to admin_places_path, notice: 'Place was successfully deleted.'
      end
    end

    private

    def place_params
      params.require(:place).permit(
        :name, :business_status, :api_status, :formatted_address,
        :formatted_phone_number, :international_phone_number,
        :website, :rating, :user_ratings_total, :price_level,
        :permanently_closed, :wheelchair_accessible_entrance
      )
    end

    def parse_opening_hours(opening_hours_json)
      return nil unless opening_hours_json.present?
      
      begin
        JSON.parse(opening_hours_json)
      rescue JSON::ParserError
        nil
      end
    end

    def parse_photos(photos_json)
      return nil unless photos_json.present?
      
      begin
        JSON.parse(photos_json)
      rescue JSON::ParserError
        nil
      end
    end

    def parse_reviews(reviews_json)
      return nil unless reviews_json.present?
      
      begin
        JSON.parse(reviews_json)
      rescue JSON::ParserError
        nil
      end
    end
  end
end
