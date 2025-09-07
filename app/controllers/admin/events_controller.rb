module Admin
  class EventsController < Admin::ApplicationController
    before_action :set_event, only: [ :show, :edit, :update, :destroy ]

    def index
      search_term = params[:search]

      @events = Event.includes(:place).all

      # Apply search filter
      if search_term.present?
        @events = @events.joins(:place).where(
          "events.title ILIKE ? OR events.description ILIKE ? OR places.name ILIKE ?",
          "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
        )
      end

      # Apply status filter
      if params[:status].present?
        case params[:status]
        when "upcoming"
          @events = @events.upcoming
        when "ongoing"
          @events = @events.ongoing
        when "past"
          @events = @events.past
        end
      end

      @events = @events.order(:starts_at).limit(50)
      @total_events = Event.count
      @upcoming_events = Event.upcoming.count
      @ongoing_events = Event.ongoing.count
      @past_events = Event.past.count
    end

    def show
      # Event details already loaded by set_event
    end

    def new
      @event = Event.new
      @places = Place.joins(:school).order("places.name")
    end

    def create
      @event = Event.new(event_params)

      if @event.save
        redirect_to admin_event_path(@event), notice: "Event was successfully created."
      else
        @places = Place.joins(:school).order("places.name")
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @places = Place.joins(:school).order("places.name")
    end

    def update
      if @event.update(event_params)
        redirect_to admin_event_path(@event), notice: "Event was successfully updated."
      else
        @places = Place.joins(:school).order("places.name")
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @event.destroy
      redirect_to admin_events_path, notice: "Event was successfully deleted."
    end

    private

    def set_event
      @event = Event.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_events_path, alert: "Event not found."
    end

    def event_params
      params.require(:event).permit(:title, :description, :starts_at, :ends_at, :location, :url, :place_id)
    end
  end
end
