module Admin
  class MediaItemsController < Admin::ApplicationController

    def index
      search_term = params[:search]
      
      @media_items = MediaItem.includes(:place).order(created_at: :desc)
      
      # Apply search filter
      if search_term.present?
        @media_items = @media_items.joins(:place).where(
          "places.name ILIKE ? OR media_items.alt_text ILIKE ? OR media_items.url ILIKE ?", 
          "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
        )
      end
      
      # Apply kind filter
      if params[:kind].present?
        @media_items = @media_items.where(kind: params[:kind])
      end
      
      # Apply place filter
      if params[:place_id].present?
        @media_items = @media_items.where(place_id: params[:place_id])
      end
      
      # Apply source filter
      if params[:source].present?
        @media_items = @media_items.where(source: params[:source])
      end
      
      @media_items = @media_items.limit(50)
      
      # Statistics
      @total_media_items = MediaItem.count
      @total_images = MediaItem.where(kind: %w[logo photo]).count
      @total_documents = MediaItem.where(kind: %w[brochure fee_schedule_pdf menu floor_plan]).count
      @total_videos = MediaItem.where(kind: %w[video virtual_tour]).count
      @places_with_media = Place.joins(:media_items).distinct.count
      
      # Kind distribution
      @kind_stats = MediaItem.group(:kind).count
      
      # Popular places for selector
      @popular_places = Place.joins(:media_items)
        .group('places.id', 'places.name')
        .order('COUNT(media_items.id) DESC')
        .limit(20)
        .pluck(:id, :name)
    end

    def show
      @media_item = MediaItem.includes(:place).find(params[:id])
    end

    def new
      @media_item = MediaItem.new
      @places = Place.where.not(name: nil).order(:name).limit(100)
    end

    def create
      @media_item = MediaItem.new(media_item_params)
      
      if @media_item.save
        redirect_to admin_media_item_path(@media_item), notice: 'Media item was successfully created.'
      else
        @places = Place.where.not(name: nil).order(:name).limit(100)
        render :new
      end
    end

    def edit
      @media_item = MediaItem.find(params[:id])
      @places = Place.where.not(name: nil).order(:name).limit(100)
    end

    def update
      @media_item = MediaItem.find(params[:id])
      
      if @media_item.update(media_item_params)
        redirect_to admin_media_item_path(@media_item), notice: 'Media item was successfully updated.'
      else
        @places = Place.where.not(name: nil).order(:name).limit(100)
        render :edit
      end
    end

    def destroy
      @media_item = MediaItem.find(params[:id])
      @media_item.destroy
      redirect_to admin_media_items_path, notice: 'Media item was successfully deleted.'
    end

    private

    def media_item_params
      params.require(:media_item).permit(:place_id, :kind, :url, :alt_text, :sort_order, :source, :file)
    end
  end
end
