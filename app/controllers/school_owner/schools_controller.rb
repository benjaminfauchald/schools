class SchoolOwner::SchoolsController < SchoolOwner::ApplicationController
  before_action :set_school, only: [:show, :edit, :update, :academic_programs, :update_academic_programs, :facilities, :update_facilities, :toggle_photo_visibility, :fetch_videos, :toggle_video_visibility, :import_website_data, :import_status]
  
  def index
    @schools = current_user.owned_schools.includes(:place)
  end
  
  def show
    @school = current_school
  end
  
  def edit
    @school = current_school
    @vocabularies = load_program_vocabularies
    @facility_vocabulary = Vocabulary.find_by(code: 'facility')
    @facility_terms = @facility_vocabulary&.terms&.includes(:parent) || []
  end
  
  def update
    @school = current_school
    @vocabularies = load_program_vocabularies
    @facility_vocabulary = Vocabulary.find_by(code: 'facility')
    @facility_terms = @facility_vocabulary&.terms&.includes(:parent) || []
    
    # Extract taxonomy parameters separately from all params
    all_params = all_school_params
    taxonomy_params = all_params.extract!(:curriculum, :accreditation, :language, :program, :facility)
    
    # Update basic school attributes
    school_updated = @school.update(school_params)
    
    # Update taxonomy if basic school data updated successfully
    taxonomy_updated = true
    if school_updated && taxonomy_params.to_h.any? { |_, v| v.present? }
      taxonomy_updated = update_school_taxonomy(taxonomy_params)
    end
    
    if school_updated && taxonomy_updated
      # Log the update
      changed_fields = school_params.keys
      changed_fields << 'academic_programs' if taxonomy_params.slice(:curriculum, :accreditation, :language, :program).to_h.any? { |_, v| v.present? }
      changed_fields << 'facilities' if taxonomy_params[:facility].present?
      
      create_audit_log(@school, 'update', changed_fields)
      
      respond_to do |format|
        format.html { redirect_to school_owner_school_path(@school), notice: 'School information updated successfully.' }
        format.json { render json: { success: true, message: 'School information updated successfully.' } }
      end
    else
      # Collect all error messages
      error_messages = []
      error_messages.concat(@school.errors.full_messages) if @school.errors.any?
      
      unless school_updated
        Rails.logger.error "School update failed: #{@school.errors.full_messages.join(', ')}"
        error_messages << "Failed to update school information"
      end
      
      unless taxonomy_updated
        Rails.logger.error "Taxonomy update failed for school #{@school.id}"
        error_messages << "Failed to update academic programs or facilities"
      end
      
      # Add detailed parameter logging for debugging
      Rails.logger.error "School params: #{school_params.inspect}"
      Rails.logger.error "Taxonomy params: #{taxonomy_params.inspect}"
      
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { 
          render json: { 
            success: false, 
            errors: error_messages.presence || ['Unknown error occurred'],
            debug: {
              school_updated: school_updated,
              taxonomy_updated: taxonomy_updated,
              school_errors: @school.errors.full_messages
            }
          } 
        }
      end
    end
  end
  
  def academic_programs
    @school = current_school
    @vocabularies = load_program_vocabularies
  end
  
  def update_academic_programs
    @school = current_school
    @vocabularies = load_program_vocabularies
    
    if update_school_taxonomy(academic_program_params)
      create_audit_log(@school, 'update', ['academic_programs'])
      respond_to do |format|
        format.html { redirect_to edit_school_owner_school_path(@school, anchor: 'academic-programs'), 
                      notice: 'Academic programs updated successfully.' }
        format.json { render json: { success: true, message: 'Academic programs updated successfully.' } }
      end
    else
      respond_to do |format|
        format.html { render :academic_programs, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: 'Failed to update academic programs' } }
      end
    end
  end
  
  def facilities
    @school = current_school
    @facility_vocabulary = Vocabulary.find_by(code: 'facility')
    @facility_terms = @facility_vocabulary&.terms&.includes(:parent) || []
  end
  
  def update_facilities
    @school = current_school
    @facility_vocabulary = Vocabulary.find_by(code: 'facility')
    @facility_terms = @facility_vocabulary&.terms&.includes(:parent) || []
    
    if update_school_taxonomy(facility_params)
      create_audit_log(@school, 'update', ['facilities'])
      respond_to do |format|
        format.html { redirect_to edit_school_owner_school_path(@school, anchor: 'facilities'), 
                      notice: 'Campus facilities updated successfully.' }
        format.json { render json: { success: true, message: 'Campus facilities updated successfully.' } }
      end
    else
      respond_to do |format|
        format.html { render :facilities, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: 'Failed to update facilities' } }
      end
    end
  end
  
  def delete_photo
    @school = current_school
    photo = @school.photos.find(params[:photo_id])
    
    if photo.purge
      create_audit_log(@school, 'delete', ['photo'])
      respond_to do |format|
        format.html { redirect_back(fallback_location: edit_school_owner_school_path(@school, anchor: 'photos'), notice: 'Photo deleted successfully.') }
        format.json { render json: { success: true, message: 'Photo deleted successfully.' } }
      end
    else
      respond_to do |format|
        format.html { redirect_back(fallback_location: edit_school_owner_school_path(@school, anchor: 'photos'), alert: 'Failed to delete photo.') }
        format.json { render json: { success: false, message: 'Failed to delete photo.' } }
      end
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_back(fallback_location: edit_school_owner_school_path(@school, anchor: 'photos'), alert: 'Photo not found.') }
      format.json { render json: { success: false, message: 'Photo not found.' } }
    end
  end
  
  def toggle_photo_visibility
    @school = current_school
    
    unless params[:photo_key].present?
      respond_to do |format|
        format.json { render json: { success: false, message: 'Photo key is required.' }, status: :bad_request }
      end
      return
    end
    
    # Find the photo by key
    photo = find_photo_by_key(params[:photo_key])
    
    unless photo
      respond_to do |format|
        format.json { render json: { success: false, message: 'Photo not found.' }, status: :not_found }
      end
      return
    end
    
    # Toggle visibility
    new_visibility = @school.toggle_photo_visibility(photo)
    
    if @school.save
      create_audit_log(@school, 'update', ['photo_visibility'])
      
      respond_to do |format|
        format.json { 
          render json: { 
            success: true, 
            visible: new_visibility,
            message: new_visibility ? 'Photo is now visible.' : 'Photo is now hidden.'
          } 
        }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, message: 'Failed to update photo visibility.', errors: @school.errors.full_messages } }
      end
    end
  end
  
  def fetch_videos
    @school = current_school
    
    unless @school.has_youtube_channel?
      respond_to do |format|
        format.json { render json: { success: false, message: 'No YouTube channel configured.' }, status: :bad_request }
      end
      return
    end
    
    # Check if we should force refresh from API
    force_refresh = params[:refresh] == 'true'
    
    # Check if videos need automatic refresh (older than 7 days)
    videos_need_refresh = @school.place.youtube_videos.any? && 
                         @school.place.youtube_videos.maximum(:updated_at) < 7.days.ago
    
    # Serve from database if we have videos and don't need refresh
    if @school.place.youtube_videos.any? && !force_refresh && !videos_need_refresh
      videos_with_visibility = @school.place.youtube_videos.ordered.map do |video|
        {
          video_id: video.video_id,
          title: video.title,
          description: video.description,
          thumbnail_url: video.hq_thumbnail_url,
          duration: video.duration_display,
          view_count: video.view_count,
          published_at: video.published_at,
          visible: video.visible,
          video_key: video.video_key,
          duration_formatted: video.duration_display,
          view_count_formatted: video.view_count_display
        }.merge(video.video_data || {})
      end
      
      last_updated = @school.place.youtube_videos.maximum(:updated_at)
      
      respond_to do |format|
        format.json { 
          render json: { 
            success: true, 
            videos: videos_with_visibility,
            channel_id: "cached",
            fetched_at: last_updated,
            from_database: true,
            cache_age_days: ((Time.current - last_updated) / 1.day).round,
            needs_refresh: videos_need_refresh
          } 
        }
      end
      return
    end
    
    # Fetch from YouTube API and save to database (either no videos or refresh needed)
    result = @school.fetch_youtube_videos
    
    if result[:success]
      # Save videos to database
      @school.place.youtube_videos.destroy_all # Clear old videos
      
      result[:videos].each_with_index do |video_data, index|
        # Check if this video should be visible based on existing visibility settings
        visible = @school.video_visible?(video_data)
        
        @school.place.youtube_videos.create!(
          video_id: video_data[:video_id] || video_data['video_id'],
          title: video_data[:title] || video_data['title'],
          description: video_data[:description] || video_data['description'],
          thumbnail_url: video_data[:thumbnail_url] || video_data['thumbnail_url'] || "https://img.youtube.com/vi/#{video_data[:video_id] || video_data['video_id']}/hqdefault.jpg",
          duration: video_data[:duration] || video_data['duration'],
          view_count: video_data[:view_count] || video_data['view_count'],
          published_at: video_data[:published_at] || video_data['published_at'],
          video_data: video_data,
          visible: visible,
          sort_order: index
        )
      end
      
      # Return the saved videos with visibility information
      videos_with_visibility = @school.place.youtube_videos.ordered.map do |video|
        {
          video_id: video.video_id,
          title: video.title,
          description: video.description,
          thumbnail_url: video.hq_thumbnail_url,
          duration: video.duration_display,
          view_count: video.view_count,
          published_at: video.published_at,
          visible: video.visible,
          video_key: video.video_key,
          duration_formatted: video.duration_display,
          view_count_formatted: video.view_count_display
        }.merge(video.video_data || {})
      end
      
      respond_to do |format|
        format.json { 
          render json: { 
            success: true, 
            videos: videos_with_visibility,
            channel_id: result[:channel_id],
            fetched_at: result[:fetched_at],
            from_database: false,
            saved_count: @school.place.youtube_videos.count,
            cache_age_days: 0,
            needs_refresh: false,
            was_refreshed: force_refresh || videos_need_refresh
          } 
        }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, message: result[:error] }, status: :bad_request }
      end
    end
  end
  
  def toggle_video_visibility
    @school = current_school
    
    unless params[:video_key].present?
      respond_to do |format|
        format.json { render json: { success: false, message: 'Video key is required.' }, status: :bad_request }
      end
      return
    end
    
    # Find the video in the database
    video = @school.place.youtube_videos.find_by(video_id: params[:video_key])
    unless video
      respond_to do |format|
        format.json { render json: { success: false, message: 'Video not found.' }, status: :not_found }
      end
      return
    end
    
    # Toggle visibility
    new_visibility = !video.visible
    
    if video.update(visible: new_visibility)
      create_audit_log(@school, 'update', ['video_visibility'])
      
      respond_to do |format|
        format.json { 
          render json: { 
            success: true, 
            visible: new_visibility,
            message: new_visibility ? 'Video is now visible.' : 'Video is now hidden.'
          } 
        }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, message: 'Failed to update video visibility.', errors: video.errors.full_messages } }
      end
    end
  end
  
  def import_website_data
    @school = current_school
    
    unless @school.website_url.present?
      respond_to do |format|
        format.json { render json: { success: false, message: 'No website URL found for this school.' }, status: :bad_request }
      end
      return
    end
    
    # Check if an import is already in progress
    if @school.website_crawling_status == 'crawling'
      respond_to do |format|
        format.json { render json: { success: false, message: 'Import already in progress.' }, status: :bad_request }
      end
      return
    end
    
    # Queue the import job
    begin
      ImportSchoolWebsiteDataJob.perform_later(@school.id)
      
      # Update status to indicate import started
      @school.update!(
        website_crawling_status: 'crawling',
        website_crawling_error: nil
      )
      
      create_audit_log(@school, 'update', ['website_crawling_status'])
      
      respond_to do |format|
        format.json { render json: { success: true, message: 'Website import started in background.' } }
      end
    rescue => e
      Rails.logger.error "Failed to start website import for school #{@school.id}: #{e.message}"
      
      respond_to do |format|
        format.json { render json: { success: false, message: 'Failed to start website import.' }, status: :internal_server_error }
      end
    end
  end
  
  def import_status
    @school = current_school
    
    status = {
      status: @school.website_crawling_status || 'none',
      last_crawled: @school.website_crawled_at,
      pages_found: @school.website_pages_found,
      error: @school.website_crawling_error
    }
    
    respond_to do |format|
      format.json { render json: status }
    end
  end
  
  private
  
  def find_photo_by_key(photo_key)
    return nil unless @school.place&.photos&.present?
    
    @school.place.photos.find do |photo|
      @school.send(:generate_photo_key, photo) == photo_key
    end
  end
  
  def set_school
    @school = current_school
  end
  
  def school_params
    params.require(:school).permit(
      :name, :about, :website_url, :admissions_url, :phone, :email,
      :address_line_1, :address_line_2, :district, :province, :postcode, :country_code,
      :facebook_url, :line_id, :whatsapp_number, :youtube_url, :linkedin_url, :twitter_url, :instagram_url,
      :founded_year, :ownership, :avg_class_size, :student_teacher_ratio,
      :boarding, :school_bus, :language_support_notes, :tone_of_voice,
      photos: []
    )
  end
  
  def all_school_params
    params.require(:school).permit(
      :name, :about, :website_url, :admissions_url, :phone, :email,
      :address_line_1, :address_line_2, :district, :province, :postcode, :country_code,
      :facebook_url, :line_id, :whatsapp_number, :youtube_url, :linkedin_url, :twitter_url, :instagram_url,
      :founded_year, :ownership, :avg_class_size, :student_teacher_ratio,
      :boarding, :school_bus, :language_support_notes, :tone_of_voice,
      photos: [], curriculum: [], accreditation: [], language: [], program: [], facility: []
    )
  end
  
  def load_program_vocabularies
    vocabulary_codes = %w[curriculum accreditation language program]
    vocabularies = {}
    
    vocabulary_codes.each do |code|
      vocab = Vocabulary.find_by(code: code)
      vocabularies[code.to_sym] = vocab&.terms&.includes(:parent) || []
    end
    
    vocabularies
  end
  
  def academic_program_params
    params.permit(
      curriculum: [],
      accreditation: [],
      language: [],
      program: []
    )
  end
  
  def facility_params
    params.permit(facility: [])
  end
  
  def update_school_taxonomy(taxonomy_params)
    success = true
    errors = []
    
    Rails.logger.info "Starting taxonomy update for school #{@school.id} with params: #{taxonomy_params.inspect}"
    
    taxonomy_params.each do |vocabulary_code, term_codes|
      next if term_codes.blank?
      
      Rails.logger.info "Processing vocabulary: #{vocabulary_code} with terms: #{term_codes.inspect}"
      
      # Remove existing taggings for this vocabulary
      vocabulary = Vocabulary.find_by(code: vocabulary_code.to_s)
      unless vocabulary
        error_msg = "Vocabulary not found for code: #{vocabulary_code}"
        Rails.logger.error error_msg
        errors << error_msg
        success = false
        next
      end
      
      # Remove existing taggings
      existing_count = @school.taggings.joins(:term)
                               .where(terms: { vocabulary_id: vocabulary.id })
                               .count
      Rails.logger.info "Removing #{existing_count} existing taggings for vocabulary #{vocabulary_code}"
      
      @school.taggings.joins(:term)
             .where(terms: { vocabulary_id: vocabulary.id })
             .destroy_all
      
      # Add new taggings
      term_codes.reject(&:blank?).each do |term_slug|
        term = vocabulary.terms.find_by(slug: term_slug)
        unless term
          error_msg = "Term not found for slug: #{term_slug} in vocabulary: #{vocabulary_code}"
          Rails.logger.error error_msg
          errors << error_msg
          success = false
          next
        end
        
        tagging = @school.taggings.build(
          term: term,
          context: vocabulary_code.to_s
        )
        
        unless tagging.save
          error_msg = "Failed to save tagging for term #{term_slug}: #{tagging.errors.full_messages.join(', ')}"
          Rails.logger.error error_msg
          errors << error_msg
          success = false
        else
          Rails.logger.info "Successfully created tagging for term: #{term_slug}"
        end
      end
    end
    
    if errors.any?
      Rails.logger.error "Taxonomy update completed with errors: #{errors.join('; ')}"
    else
      Rails.logger.info "Taxonomy update completed successfully"
    end
    
    success
  rescue => e
    error_msg = "Exception in taxonomy update: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    Rails.logger.error error_msg
    false
  end

  def create_audit_log(school, action, changed_fields)
    return unless defined?(AuditLog)
    
    AuditLog.create!(
      auditable: school,
      user_id: current_user.id,
      action: action,
      changed_fields: { updated_fields: changed_fields }
    )
  end
end