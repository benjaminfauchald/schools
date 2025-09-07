module Admin
  class TermsController < Admin::ApplicationController
    def index
      search_term = params[:search]

      @terms = Term.includes(:vocabulary, :parent, :children, :taggings).order(:label)

      # Apply search filter
      if search_term.present?
        @terms = @terms.search(search_term)
      end

      # Apply vocabulary filter
      if params[:vocabulary_id].present?
        @terms = @terms.where(vocabulary_id: params[:vocabulary_id])
      end

      # Apply status filter
      case params[:status]
      when "active"
        @terms = @terms.active
      when "inactive"
        @terms = @terms.where(is_active: false)
      when "root"
        @terms = @terms.roots
      when "children"
        @terms = @terms.where.not(parent_id: nil)
      end

      @terms = @terms.limit(50)

      # Statistics
      @total_terms = Term.count
      @active_terms = Term.active.count
      @root_terms = Term.roots.count
      @terms_with_children = Term.joins(:children).distinct.count
      @vocabularies_count = Vocabulary.count
      @usage_count = Term.joins(:taggings).distinct.count

      # Vocabulary data
      @vocabularies = Vocabulary.ordered.limit(20)
      @vocabulary_stats = Vocabulary.joins(:terms).group("vocabularies.id", "vocabularies.label").count
    end

    def show
      @term = find_resource(params[:id])
      @breadcrumbs = build_breadcrumbs(@term)
    end

    def new
      @term = Term.new
      @vocabularies = Vocabulary.ordered
      @potential_parents = []
    end

    def create
      @term = Term.new(term_params)

      if @term.save
        redirect_to admin_term_path(@term), notice: "Term was successfully created."
      else
        @vocabularies = Vocabulary.ordered
        @potential_parents = @term.vocabulary ? @term.vocabulary.terms.where.not(id: @term.id) : []
        render :new
      end
    end

    def edit
      @term = find_resource(params[:id])
      @vocabularies = Vocabulary.ordered
      @potential_parents = @term.vocabulary ? @term.vocabulary.terms.where.not(id: @term.id) : []
    end

    def update
      @term = find_resource(params[:id])

      if @term.update(term_params)
        redirect_to admin_term_path(@term), notice: "Term was successfully updated."
      else
        @vocabularies = Vocabulary.ordered
        @potential_parents = @term.vocabulary ? @term.vocabulary.terms.where.not(id: @term.id) : []
        render :edit
      end
    end

    def destroy
      @term = find_resource(params[:id])

      if @term.children.any?
        redirect_to admin_terms_path, alert: "Cannot delete term with child terms. Please reassign or delete child terms first."
      elsif @term.taggings.any?
        redirect_to admin_terms_path, alert: "Cannot delete term that is currently in use. Please remove all usages first."
      else
        @term.destroy
        redirect_to admin_terms_path, notice: "Term was successfully deleted."
      end
    end

    private

    def find_resource(param)
      # First try to find by numeric ID, then by slug
      if param.match?(/\A\d+\z/)
        Term.find(param)
      else
        Term.find_by!(slug: param)
      end
    end

    def term_params
      params.require(:term).permit(:vocabulary_id, :parent_id, :label, :slug, :description, :is_active, :metadata)
    end

    def build_breadcrumbs(term)
      breadcrumbs = []
      current = term
      while current
        breadcrumbs.unshift(current)
        current = current.parent
      end
      breadcrumbs
    end
  end
end
