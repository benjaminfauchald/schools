module Admin
  class TravelTimesController < Admin::ApplicationController
    def index
      search_term = params[:search]

      @travel_times = TravelTime.includes(:place).order(created_at: :desc)

      # Apply search filter
      if search_term.present?
        @travel_times = @travel_times.joins(:place).where(
          "places.name ILIKE ? OR travel_times.origin_hash ILIKE ?",
          "%#{search_term}%", "%#{search_term}%"
        )
      end

      # Apply mode filter
      if params[:mode].present?
        @travel_times = @travel_times.where(mode: params[:mode])
      end

      # Apply status filter
      case params[:status]
      when "successful"
        @travel_times = @travel_times.successful
      when "failed"
        @travel_times = @travel_times.failed
      when "stale"
        @travel_times = @travel_times.stale
      when "recent"
        @travel_times = @travel_times.recent
      end

      @travel_times = @travel_times.limit(50)

      # Statistics
      @total_travel_times = TravelTime.count
      @successful_times = TravelTime.successful.count
      @failed_times = TravelTime.failed.count
      @stale_times = TravelTime.stale.count
      @avg_driving_time = TravelTime.successful.by_mode("driving").average(:minutes)&.round(1)
      @avg_transit_time = TravelTime.successful.by_mode("transit").average(:minutes)&.round(1)

      # Mode distribution
      @mode_stats = TravelTime.group(:mode).count
    end

    def show
      @travel_time = TravelTime.includes(:place).find(params[:id])
    end

    def new
      @travel_time = TravelTime.new
      @places = Place.where.not(name: nil).order(:name).limit(100)
    end

    def create
      @travel_time = TravelTime.new(travel_time_params)

      if @travel_time.save
        redirect_to admin_travel_time_path(@travel_time), notice: "Travel time was successfully created."
      else
        @places = Place.where.not(name: nil).order(:name).limit(100)
        render :new
      end
    end

    def edit
      @travel_time = TravelTime.find(params[:id])
      @places = Place.where.not(name: nil).order(:name).limit(100)
    end

    def update
      @travel_time = TravelTime.find(params[:id])

      if @travel_time.update(travel_time_params)
        redirect_to admin_travel_time_path(@travel_time), notice: "Travel time was successfully updated."
      else
        @places = Place.where.not(name: nil).order(:name).limit(100)
        render :edit
      end
    end

    def destroy
      @travel_time = TravelTime.find(params[:id])
      @travel_time.destroy
      redirect_to admin_travel_times_path, notice: "Travel time was successfully deleted."
    end

    private

    def travel_time_params
      params.require(:travel_time).permit(:place_id, :origin_hash, :mode, :minutes, :computed_at)
    end
  end
end
