module Admin
  class VocabulariesController < Admin::ApplicationController
    before_action :set_vocabulary, only: [:show, :edit, :update, :destroy]
    
    def index
      search_term = params[:search]
      
      @vocabularies = Vocabulary.includes(:terms).all
      
      # Apply search filter
      if search_term.present?
        @vocabularies = @vocabularies.where(
          "vocabularies.code ILIKE ? OR vocabularies.label ILIKE ? OR vocabularies.description ILIKE ?", 
          "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
        )
      end
      
      # Apply status filter
      if params[:usage].present?
        case params[:usage]
        when 'used'
          @vocabularies = @vocabularies.joins(terms: :taggings).distinct
        when 'unused'
          @vocabularies = @vocabularies.left_joins(terms: :taggings)
                           .where(taggings: { id: nil })
        end
      end
      
      @vocabularies = @vocabularies.ordered.limit(50)
      @total_vocabularies = Vocabulary.count
      @used_vocabularies = Vocabulary.joins(terms: :taggings).distinct.count
      @unused_vocabularies = @total_vocabularies - @used_vocabularies
    end

    def show
      # Vocabulary details already loaded by set_vocabulary
    end

    def new
      @vocabulary = Vocabulary.new
    end

    def create
      @vocabulary = Vocabulary.new(vocabulary_params)
      
      if @vocabulary.save
        redirect_to admin_vocabulary_path(@vocabulary), notice: 'Vocabulary was successfully created.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      # Vocabulary already loaded by set_vocabulary
    end

    def update
      if @vocabulary.update(vocabulary_params)
        redirect_to admin_vocabulary_path(@vocabulary), notice: 'Vocabulary was successfully updated.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @vocabulary.terms.joins(:taggings).any?
        redirect_to admin_vocabularies_path, alert: 'Cannot delete vocabulary with terms that are in use.'
      else
        @vocabulary.destroy
        redirect_to admin_vocabularies_path, notice: 'Vocabulary was successfully deleted.'
      end
    end

    private

    def set_vocabulary
      if params[:id].to_s.match?(/\A\d+\z/) # If param is numeric, use regular ID lookup
        @vocabulary = Vocabulary.find(params[:id])
      else # If param is non-numeric, assume it's a code
        @vocabulary = Vocabulary.find_by!(code: params[:id])
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_vocabularies_path, alert: 'Vocabulary not found.'
    end

    def vocabulary_params
      params.require(:vocabulary).permit(:code, :label, :description)
    end
  end
end
