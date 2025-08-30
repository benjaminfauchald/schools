class SchoolOwner::PagesController < SchoolOwner::ApplicationController
  before_action :set_school
  before_action :set_page, only: [:show, :edit, :update, :destroy]

  def index
    @pages = @school.pages.order(:created_at)
  end

  def generate_content
    title = params[:title]
    description = params[:description] || ''
    
    unless title.present?
      render json: { error: 'Title is required' }, status: :unprocessable_entity
      return
    end

    begin
      generator = SchoolContentGenerator.new(@school, title, description)
      content = generator.generate_ai_content_only
      
      if content
        render json: { 
          success: true, 
          content: content[:html_content],
          meta_description: content[:meta_description]
        }
      else
        render json: { error: 'Failed to generate content' }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "Error generating content: #{e.message}"
      render json: { error: 'An error occurred while generating content' }, status: :internal_server_error
    end
  end

  def show
    redirect_to school_page_path(@school, @page)
  end

  def new
    @page = @school.pages.build
  end

  def create
    Rails.logger.info "=== Page Create/Update Request ==="
    Rails.logger.info "Page ID parameter: #{params[:page_id]}"
    Rails.logger.info "Page params: #{page_params.inspect}"
    Rails.logger.info "Content received: #{page_params[:content]&.truncate(300) || 'nil'}"
    Rails.logger.info "Content length: #{page_params[:content]&.length || 0}"
    
    # Check if this is actually an update based on page_id parameter
    if params[:page_id].present?
      @page = @school.pages.find(params[:page_id])
      Rails.logger.info "Updating existing page: #{@page.id}"
      
      if @page.update(page_params)
        Rails.logger.info "Page updated successfully. Content after save: #{@page.content.body.to_s.truncate(300) rescue 'error'}"
        redirect_to edit_school_owner_school_path(@school, anchor: 'pages'), 
                    notice: 'Page was successfully updated.'
      else
        Rails.logger.error "Page update failed: #{@page.errors.full_messages.join(', ')}"
        redirect_to edit_school_owner_school_path(@school, anchor: 'pages'), 
                    alert: "Error updating page: #{@page.errors.full_messages.join(', ')}"
      end
    else
      @page = @school.pages.build(page_params)
      Rails.logger.info "Creating new page"
      
      if @page.save
        Rails.logger.info "Page created successfully. Content after save: #{@page.content.body.to_s.truncate(300) rescue 'error'}"
        redirect_to edit_school_owner_school_path(@school, anchor: 'pages'), 
                    notice: 'Page was successfully created.'
      else
        Rails.logger.error "Page creation failed: #{@page.errors.full_messages.join(', ')}"
        redirect_to edit_school_owner_school_path(@school, anchor: 'pages'), 
                    alert: "Error creating page: #{@page.errors.full_messages.join(', ')}"
      end
    end
  end

  def edit
  end

  def update
    if @page.update(page_params)
      redirect_to edit_school_owner_school_path(@school, anchor: 'pages'), 
                  notice: 'Page was successfully updated.'
    else
      redirect_to edit_school_owner_school_path(@school, anchor: 'pages'), 
                  alert: "Error updating page: #{@page.errors.full_messages.join(', ')}"
    end
  end

  def destroy
    @page.destroy
    redirect_to edit_school_owner_school_path(@school, anchor: 'pages'), 
                notice: 'Page was successfully deleted.'
  end

  private

  def set_school
    @school = current_user.owned_schools.find(params[:school_id])
  end

  def set_page
    @page = @school.pages.find(params[:id])
  end

  def page_params
    params.require(:page).permit(:title, :content, :meta_description, :page_type, :status)
  end
end