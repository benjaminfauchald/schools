module Admin
  class PointsController < Admin::ApplicationController
    def index
      search_term = params[:search]
      
      @points = Point.includes(:places).order(:id)
      
      # Apply search filter
      if search_term.present?
        @points = @points.where(
          "name ILIKE ? OR address ILIKE ? OR addr_street ILIKE ? OR addr_city ILIKE ?", 
          "%#{search_term}%", "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
        )
      end
      
      # Apply amenity filter
      if params[:amenity].present?
        @points = @points.where("amenity ILIKE ?", "%#{params[:amenity]}%")
      end
      
      # Apply city filter
      if params[:city].present?
        @points = @points.where("addr_city ILIKE ?", "%#{params[:city]}%")
      end
      
      @points = @points.limit(50)
      
      # Statistics
      @total_points = Point.count
      @points_with_amenity = Point.where.not(amenity: nil).count
      @named_points = Point.where.not(name: nil).count
      @points_with_contact = Point.where.not(phone: nil).count
      @points_with_places = Point.joins(:places).distinct.count
      
      # Amenity breakdown
      @amenity_counts = Point.where.not(amenity: nil).group(:amenity).count
      @city_counts = Point.where.not(addr_city: nil).group(:addr_city).count
    end
    
    def show
      @point = Point.includes(:places).find(params[:id])
    end
    
    def new
      @point = Point.new
    end
    
    def create
      @point = Point.new(point_params)
      
      if @point.save
        redirect_to admin_point_path(@point), notice: 'Point was successfully created.'
      else
        render :new
      end
    end
    
    def edit
      @point = Point.find(params[:id])
    end
    
    def update
      @point = Point.find(params[:id])
      
      if @point.update(point_params)
        redirect_to admin_point_path(@point), notice: 'Point was successfully updated.'
      else
        render :edit
      end
    end
    
    def destroy
      @point = Point.find(params[:id])
      @point.destroy
      redirect_to admin_points_path, notice: 'Point was successfully deleted.'
    end

    private
    
    def point_params
      params.require(:point).permit(
        :osm_id, :name, :address, :addr_street, :addr_city, :addr_district, :addr_province, 
        :addr_postcode, :addr_country, :amenity, :school_type, :operator, :phone, 
        :website, :email, :lat, :lon
      )
    end
  end
end
