class SchoolOwner::BlogPostsController < SchoolOwner::BaseController
  before_action :set_place, only: [:new, :generate, :preview, :topics]
  before_action :ensure_content_available, only: [:new, :generate]
  
  def new
    @suggested_topics = suggest_topics_from_content(@place)
    @content_summary = @place.content_summary
    @content_readiness = @place.content_readiness_percentage
  end
  
  def generate
    Rails.logger.info "Blog generation requested by user #{current_user.id} for place #{@place.id}"
    
    result = BlogGenerationService.generate_for_place(
      @place.id,
      params[:topic],
      word_count: params[:word_count]&.to_i || 800,
      tone: params[:tone] || 'informative',
      audience: params[:audience] || 'parents and students',
      content_types: params[:content_types] || ['transcript', 'pdf_document'],
      publish_immediately: params[:publish_immediately] == 'true'
    )
    
    if result[:success]
      flash[:notice] = build_success_message(result)
      
      if result[:blog_post].respond_to?(:id)
        # Redirect to edit the generated blog post
        redirect_to edit_school_owner_place_page_path(@place, result[:blog_post])
      else
        # Redirect back with success message
        redirect_to new_school_owner_place_blog_post_path(@place)
      end
    else
      flash[:alert] = build_error_message(result)
      redirect_to new_school_owner_place_blog_post_path(@place, 
                    topic: params[:topic],
                    word_count: params[:word_count],
                    tone: params[:tone],
                    audience: params[:audience])
    end
  rescue => e
    Rails.logger.error "Unexpected error in blog generation controller: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    flash[:alert] = "An unexpected error occurred while generating the blog post. Please try again."
    redirect_to new_school_owner_place_blog_post_path(@place)
  end
  
  def preview
    if params[:topic].blank?
      render json: { error: 'Topic is required' }, status: 400
      return
    end
    
    context_preview = BlogGenerationService.preview_context_for_topic(
      @place.id,
      params[:topic],
      preview_tokens: 1000,
      content_types: params[:content_types] || ['transcript', 'pdf_document', 'text_document']
    )
    
    render json: {
      success: true,
      preview: context_preview,
      place_name: @place.name
    }
  rescue => e
    Rails.logger.error "Error in preview: #{e.message}"
    
    render json: { 
      success: false,
      error: "Failed to generate preview: #{e.message}" 
    }, status: 500
  end
  
  def topics
    suggestions = BlogGenerationService.suggest_topics_for_place(
      @place.id,
      limit: params[:limit]&.to_i || 10
    )
    
    render json: suggestions
  rescue => e
    Rails.logger.error "Error generating topic suggestions: #{e.message}"
    
    render json: {
      success: false,
      error: "Failed to generate topic suggestions: #{e.message}",
      suggestions: []
    }, status: 500
  end
  
  private
  
  def set_place
    @place = current_user.owned_places.find(params[:place_id])
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Place not found or you don't have permission to access it."
    redirect_to school_owner_dashboard_index_path
  end
  
  def ensure_content_available
    unless @place.has_content_for_blog_generation?
      flash[:alert] = "No processed content available for blog generation. Please upload and process transcripts or documents first."
      redirect_to school_owner_place_path(@place)
    end
  end
  
  def suggest_topics_from_content(place)
    suggestions = BlogGenerationService.suggest_topics_for_place(place.id, limit: 8)
    
    if suggestions[:success]
      suggestions[:suggestions].map { |s| s[:topic] }
    else
      # Fallback suggestions
      [
        "Our Educational Philosophy and Approach",
        "Student Life and Campus Culture", 
        "Academic Programs and Curriculum",
        "Faculty and Teaching Excellence",
        "Facilities and Learning Environment",
        "Student Support and Services"
      ]
    end
  end
  
  def build_success_message(result)
    sources_count = result[:sources_used]&.length || 0
    word_count = result[:content_stats][:generated_content_length] || 0
    
    message = "Blog post generated successfully"
    message += " using #{sources_count} content sources" if sources_count > 0
    message += " (~#{word_count} characters)" if word_count > 0
    message += "!"
    
    message
  end
  
  def build_error_message(result)
    case result[:error]
    when /No relevant content found/
      "No relevant content found for this topic. Try a different topic or upload more content related to this subject."
    when /Azure OpenAI/
      "Failed to generate content due to AI service error. Please try again in a few minutes."
    when /API key|configuration/i
      "Blog generation service is not properly configured. Please contact support."
    else
      result[:error] || "Failed to generate blog post. Please try again."
    end
  end
end