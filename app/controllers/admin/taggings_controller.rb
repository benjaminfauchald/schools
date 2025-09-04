module Admin
  class TaggingsController < Admin::ApplicationController
    before_action :set_tagging, only: [:show, :edit, :update, :destroy]
    
    def index
      search_term = params[:search]
      
      @taggings = Tagging.includes(:term, :taggable).all
      
      # Apply search filter
      if search_term.present?
        @taggings = @taggings.joins(:term).where(
          "terms.name ILIKE ? OR taggings.context ILIKE ? OR taggings.notes ILIKE ?", 
          "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
        )
      end
      
      # Apply context filter
      if params[:context].present?
        @taggings = @taggings.where(context: params[:context])
      end
      
      # Apply validity filter
      if params[:validity].present?
        case params[:validity]
        when 'valid'
          @taggings = @taggings.valid_at(Date.current)
        when 'expired'
          @taggings = @taggings.where('valid_to < ?', Date.current)
        when 'expiring_soon'
          @taggings = @taggings.where(valid_to: Date.current..(Date.current + 30.days))
        end
      end
      
      # Apply taggable type filter
      if params[:taggable_type].present?
        @taggings = @taggings.where(taggable_type: params[:taggable_type])
      end
      
      @taggings = @taggings.order(created_at: :desc).limit(50)
      @total_taggings = Tagging.count
      @valid_taggings = Tagging.valid_at(Date.current).count
      @expired_taggings = Tagging.where('valid_to < ?', Date.current).count
      @contexts = Tagging.distinct.pluck(:context).compact.sort
      @taggable_types = Tagging.distinct.pluck(:taggable_type).compact.sort
    end

    def show
      # Tagging details already loaded by set_tagging
    end

    def new
      @tagging = Tagging.new
      load_form_data
    end

    def create
      @tagging = Tagging.new(tagging_params)
      
      if @tagging.save
        redirect_to admin_tagging_path(@tagging), notice: 'Tagging was successfully created.'
      else
        load_form_data
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_form_data
    end

    def update
      if @tagging.update(tagging_params)
        redirect_to admin_tagging_path(@tagging), notice: 'Tagging was successfully updated.'
      else
        load_form_data
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @tagging.destroy
      redirect_to admin_taggings_path, notice: 'Tagging was successfully deleted.'
    end

    private

    def set_tagging
      @tagging = Tagging.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_taggings_path, alert: 'Tagging not found.'
    end

    def load_form_data
      @vocabularies = Vocabulary.ordered
      @terms = Term.includes(:vocabulary).ordered
      @places = Place.joins(:school).order('places.name')
    end

    def tagging_params
      params.require(:tagging).permit(:context, :notes, :taggable_type, :taggable_id, :term_id, :valid_from, :valid_to)
    end
  end
end
