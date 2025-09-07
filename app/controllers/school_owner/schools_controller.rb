class SchoolOwner::SchoolsController < SchoolOwner::ApplicationController
  before_action :set_school, only: [ :show, :edit, :update, :academic_programs, :update_academic_programs, :facilities, :update_facilities, :toggle_photo_visibility, :fetch_videos, :toggle_video_visibility, :generate_transcript, :toggle_transcript_ai, :import_website_data, :import_status, :upload_document, :delete_document, :toggle_document_ai, :reprocess_document, :download_document, :ai_chat, :ai_chat_message, :ai_suggestions, :ai_analysis ]

  def index
    @schools = current_user.owned_schools.includes(:place)
  end

  # AI Chat functionality
  def ai_chat
    @conversation = get_or_create_conversation
    @messages = @conversation.ai_messages.recent.includes(:ai_conversation)
    @suggested_questions = get_suggested_questions if @messages.empty?
    @school_summary = get_school_summary
    @completeness_score = calculate_completeness_score

    respond_to do |format|
      format.html { render "school_owner/schools/ai_chat" }
      format.json { render json: chat_data }
    end
  end

  def ai_chat_message
    Rails.logger.info "🤖 AI Chat Message Request Started"
    Rails.logger.info "📝 User Message: #{params[:message]&.truncate(100)}"
    Rails.logger.info "🏫 School ID: #{@school.id}"
    Rails.logger.info "👤 User ID: #{current_user.id}"

    user_message = params[:message]&.strip

    if user_message.blank?
      Rails.logger.warn "❌ Empty message received"
      render json: { success: false, error: "Message cannot be empty" }, status: :unprocessable_entity
      return
    end

    begin
      Rails.logger.info "🔄 Getting or creating conversation..."
      @conversation = get_or_create_conversation
      Rails.logger.info "💬 Using conversation ID: #{@conversation.id}"

      # Generate AI response using the service
      Rails.logger.info "🚀 Initializing AiChatService..."
      ai_service = AiChatService.new(@conversation)

      Rails.logger.info "🎯 Calling generate_response..."
      result = ai_service.generate_response(user_message)

      Rails.logger.info "📊 AI Service Result: success=#{result[:success]}"
      if result[:error]
        Rails.logger.error "🚨 AI Service Error: #{result[:error]}"
      end

      if result[:success]
        Rails.logger.info "✅ AI Response successful, formatting response..."
        render json: {
          success: true,
          user_message: format_message(result[:user_message]),
          assistant_message: format_message(result[:assistant_message]),
          context_data: result[:context_data],
          conversation_id: @conversation.id
        }
      else
        Rails.logger.error "❌ AI Service failed: #{result[:error]}"
        render json: {
          success: false,
          error: result[:error],
          assistant_message: result[:assistant_message] ? format_message(result[:assistant_message]) : nil
        }, status: :unprocessable_entity
      end

    rescue => e
      Rails.logger.error "💥 EXCEPTION in ai_chat_message: #{e.class.name}: #{e.message}"
      Rails.logger.error "📍 Backtrace:"
      e.backtrace.first(10).each { |line| Rails.logger.error "   #{line}" }

      render json: {
        success: false,
        error: "Sorry, I encountered an error processing your message. Please try again.",
        details: Rails.env.development? ? "#{e.class.name}: #{e.message}" : nil
      }, status: :internal_server_error
    end
  end

  def ai_suggestions
    begin
      @conversation = get_or_create_conversation
      ai_service = AiChatService.new(@conversation)
      result = ai_service.generate_suggested_questions(limit: 5)

      if result[:success]
        render json: {
          success: true,
          questions: result[:questions],
          school_summary: result[:school_summary]
        }
      else
        render json: {
          success: false,
          error: result[:error],
          questions: result[:questions] # fallback questions
        }, status: :unprocessable_entity
      end

    rescue => e
      Rails.logger.error "AI Suggestions Error: #{e.message}"

      render json: {
        success: false,
        error: "Unable to generate suggestions at this time",
        questions: default_suggested_questions
      }, status: :internal_server_error
    end
  end

  def ai_analysis
    begin
      @conversation = get_or_create_conversation
      ai_service = AiChatService.new(@conversation)
      result = ai_service.analyze_data_gaps

      if result[:success]
        render json: {
          success: true,
          analysis: result[:analysis],
          suggestions: result[:suggestions],
          message: result[:message] ? format_message(result[:message]) : nil
        }
      else
        render json: {
          success: false,
          error: result[:error]
        }, status: :unprocessable_entity
      end

    rescue => e
      Rails.logger.error "AI Analysis Error: #{e.message}"

      render json: {
        success: false,
        error: "Unable to analyze school data at this time"
      }, status: :internal_server_error
    end
  end

  def sources_count
    begin
      @school = current_school unless @school
      Rails.logger.info "🔍 Sources count request for school: #{@school.id}"

      # Count total available sources for this school
      total_sources = 0

      # Count documents that are AI-enabled (with error handling)
      begin
        if @school.place&.respond_to?(:documents)
          doc_count = @school.place.documents.where(ai_enabled: true).count
          total_sources += doc_count
          Rails.logger.info "📄 Documents: #{doc_count}"
        end
      rescue => e
        Rails.logger.error "Error counting documents: #{e.message}"
      end

      # Count videos with completed transcripts (with error handling)
      begin
        if @school.place && @school.place.respond_to?(:youtube_videos)
          # Count videos that have completed transcripts AND are AI-enabled
          video_count = @school.place.youtube_videos
            .joins("INNER JOIN transcripts ON transcripts.place_id = youtube_videos.place_id AND transcripts.video_id = youtube_videos.video_id")
            .where("transcripts.status = 'completed' AND transcripts.ai_enabled = true")
            .count
          total_sources += video_count
          Rails.logger.info "🎥 Videos with transcripts: #{video_count}"
        else
          Rails.logger.info "🎥 No place or YouTube videos available"
        end
      rescue => e
        Rails.logger.error "Error counting video transcripts: #{e.message}"
      end

      # Count school data fields (basic profile fields that have content)
      school_fields = [ "about", "mission", "vision", "accreditation" ]
      school_fields_count = 0
      school_fields.each do |field|
        begin
          if @school.respond_to?(field) && @school.send(field).present?
            school_fields_count += 1
          end
        rescue => e
          Rails.logger.error "Error checking field #{field}: #{e.message}"
        end
      end
      total_sources += school_fields_count
      Rails.logger.info "🏫 School fields: #{school_fields_count}"

      # Count place data fields from Google Places
      place_fields_count = 0
      if @school.place
        place_fields = [ "website", "phone", "formatted_address", "business_status" ]
        place_fields.each do |field|
          begin
            if @school.place.respond_to?(field) && @school.place.send(field).present?
              place_fields_count += 1
            end
          rescue => e
            Rails.logger.error "Error checking place field #{field}: #{e.message}"
          end
        end
      end
      total_sources += place_fields_count
      Rails.logger.info "📍 Place fields: #{place_fields_count}"

      Rails.logger.info "✅ Total sources: #{total_sources}"

      render json: {
        success: true,
        total_sources: total_sources,
        breakdown: {
          documents: doc_count || 0,
          videos: video_count || 0,
          school_fields: school_fields_count || 0,
          place_fields: place_fields_count || 0
        }
      }

    rescue => e
      Rails.logger.error "Sources Count Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      render json: {
        success: false,
        error: "Unable to count sources at this time",
        total_sources: 0
      }
    end
  end

  def show
    @school = current_school
  end

  def edit
    @school = current_school
    @vocabularies = load_program_vocabularies
    @facility_vocabulary = Vocabulary.find_by(code: "facility")
    @facility_terms = @facility_vocabulary&.terms&.includes(:parent) || []
  end

  def update
    @school = current_school
    @vocabularies = load_program_vocabularies
    @facility_vocabulary = Vocabulary.find_by(code: "facility")
    @facility_terms = @facility_vocabulary&.terms&.includes(:parent) || []

    # Handle photo uploads separately
    photos_uploaded = false
    if params[:school] && params[:school][:photos].present?
      photos_uploaded = handle_photo_uploads(params[:school][:photos])
    end

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
      changed_fields << "academic_programs" if taxonomy_params.slice(:curriculum, :accreditation, :language, :program).to_h.any? { |_, v| v.present? }
      changed_fields << "facilities" if taxonomy_params[:facility].present?
      changed_fields << "photos" if photos_uploaded

      create_audit_log(@school, "update", changed_fields)

      respond_to do |format|
        format.html { redirect_to school_owner_school_path(@school), notice: "School information updated successfully." }
        format.json {
          render json: {
            success: true,
            message: "School information updated successfully.",
            photos_uploaded: photos_uploaded,
            photos_count: @school.uploaded_photos.count
          }
        }
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
            errors: error_messages.presence || [ "Unknown error occurred" ],
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
      create_audit_log(@school, "update", [ "academic_programs" ])
      respond_to do |format|
        format.html { redirect_to edit_school_owner_school_path(@school, anchor: "academic-programs"),
                      notice: "Academic programs updated successfully." }
        format.json { render json: { success: true, message: "Academic programs updated successfully." } }
      end
    else
      respond_to do |format|
        format.html { render :academic_programs, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: "Failed to update academic programs" } }
      end
    end
  end

  def facilities
    @school = current_school
    @facility_vocabulary = Vocabulary.find_by(code: "facility")
    @facility_terms = @facility_vocabulary&.terms&.includes(:parent) || []
  end

  def update_facilities
    @school = current_school
    @facility_vocabulary = Vocabulary.find_by(code: "facility")
    @facility_terms = @facility_vocabulary&.terms&.includes(:parent) || []

    if update_school_taxonomy(facility_params)
      create_audit_log(@school, "update", [ "facilities" ])
      respond_to do |format|
        format.html { redirect_to edit_school_owner_school_path(@school, anchor: "facilities"),
                      notice: "Campus facilities updated successfully." }
        format.json { render json: { success: true, message: "Campus facilities updated successfully." } }
      end
    else
      respond_to do |format|
        format.html { render :facilities, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: "Failed to update facilities" } }
      end
    end
  end

  def delete_photo
    @school = current_school

    # Handle both old Active Storage photos and new MediaItem photos
    if params[:media_item_id]
      delete_media_item
    elsif params[:photo_id]
      # Legacy Active Storage photo handling
      photo = @school.photos.find(params[:photo_id])

      if photo.purge
        create_audit_log(@school, "delete", [ "photo" ])
        respond_to do |format|
          format.html { redirect_back(fallback_location: edit_school_owner_school_path(@school, anchor: "photos"), notice: "Photo deleted successfully.") }
          format.json { render json: { success: true, message: "Photo deleted successfully." } }
        end
      else
        respond_to do |format|
          format.html { redirect_back(fallback_location: edit_school_owner_school_path(@school, anchor: "photos"), alert: "Failed to delete photo.") }
          format.json { render json: { success: false, message: "Failed to delete photo." } }
        end
      end
    else
      respond_to do |format|
        format.html { redirect_back(fallback_location: edit_school_owner_school_path(@school, anchor: "photos"), alert: "Photo ID required.") }
        format.json { render json: { success: false, message: "Photo ID required." } }
      end
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_back(fallback_location: edit_school_owner_school_path(@school, anchor: "photos"), alert: "Photo not found.") }
      format.json { render json: { success: false, message: "Photo not found." } }
    end
  end

  def delete_media_item
    @school = current_school
    media_item = @school.place.media_items.find(params[:media_item_id])

    unless media_item.from_school_upload?
      respond_to do |format|
        format.html { redirect_back(fallback_location: edit_school_owner_school_path(@school, anchor: "photos"), alert: "Cannot delete this photo.") }
        format.json { render json: { success: false, message: "Cannot delete this photo." } }
      end
      return
    end

    if media_item.destroy
      create_audit_log(@school, "delete", [ "photo" ])
      respond_to do |format|
        format.html { redirect_back(fallback_location: edit_school_owner_school_path(@school, anchor: "photos"), notice: "Photo deleted successfully.") }
        format.json { render json: { success: true, message: "Photo deleted successfully." } }
      end
    else
      respond_to do |format|
        format.html { redirect_back(fallback_location: edit_school_owner_school_path(@school, anchor: "photos"), alert: "Failed to delete photo.") }
        format.json { render json: { success: false, message: "Failed to delete photo." } }
      end
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_back(fallback_location: edit_school_owner_school_path(@school, anchor: "photos"), alert: "Photo not found.") }
      format.json { render json: { success: false, message: "Photo not found." } }
    end
  end

  def toggle_photo_visibility
    @school = current_school

    unless params[:photo_key].present?
      respond_to do |format|
        format.json { render json: { success: false, message: "Photo key is required." }, status: :bad_request }
      end
      return
    end

    # Find the photo by key
    photo = find_photo_by_key(params[:photo_key])

    unless photo
      respond_to do |format|
        format.json { render json: { success: false, message: "Photo not found." }, status: :not_found }
      end
      return
    end

    # Toggle visibility
    new_visibility = @school.toggle_photo_visibility(photo)

    if @school.save
      create_audit_log(@school, "update", [ "photo_visibility" ])

      respond_to do |format|
        format.json {
          render json: {
            success: true,
            visible: new_visibility,
            message: new_visibility ? "Photo is now visible." : "Photo is now hidden."
          }
        }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, message: "Failed to update photo visibility.", errors: @school.errors.full_messages } }
      end
    end
  end

  def fetch_videos
    @school = current_school

    unless @school.has_youtube_channel?
      respond_to do |format|
        format.json { render json: { success: false, message: "No YouTube channel configured." }, status: :bad_request }
      end
      return
    end

    # Handle lightweight polling requests (just return current transcript status)
    if params[:poll_only] == "true"
      Rails.logger.info "📊 POLL: Polling request for school #{@school.id}"

      videos_with_status = @school.place.youtube_videos.ordered.map do |video|
        transcript_status = video.transcript_processing_status
        Rails.logger.info "📊 POLL: Video #{video.video_id} status: #{transcript_status[:status]}"
        {
          video_id: video.video_id,
          video_key: video.video_key,
          transcript_status: transcript_status,
          has_transcript: video.has_transcript?,
          can_retry_transcript: video.can_retry_transcript?
        }
      end

      processing_count = videos_with_status.count { |v| v[:transcript_status][:status] == "processing" }
      Rails.logger.info "📊 POLL: Returning #{videos_with_status.length} videos, #{processing_count} processing"

      respond_to do |format|
        format.json {
          render json: {
            success: true,
            videos: videos_with_status,
            poll_only: true
          }
        }
      end
      return
    end

    # Check if we should force refresh from API
    force_refresh = params[:refresh] == "true"

    # Check if videos need automatic refresh (older than 7 days)
    videos_need_refresh = @school.place.youtube_videos.any? &&
                         @school.place.youtube_videos.maximum(:updated_at) < 7.days.ago

    # Serve from database if we have videos and don't need refresh
    if @school.place.youtube_videos.any? && !force_refresh && !videos_need_refresh
      videos_with_visibility = @school.place.youtube_videos.ordered.map do |video|
        transcript_status = video.transcript_processing_status
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
          view_count_formatted: video.view_count_display,
          transcript_status: transcript_status,
          has_transcript: video.has_transcript?,
          can_retry_transcript: video.can_retry_transcript?,
          transcript_segments_count: video.transcript_segments_count
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

      created_videos = []
      result[:videos].each_with_index do |video_data, index|
        # Check if this video should be visible based on existing visibility settings
        visible = @school.video_visible?(video_data)

        video = @school.place.youtube_videos.create!(
          video_id: video_data[:video_id] || video_data["video_id"],
          title: video_data[:title] || video_data["title"],
          description: video_data[:description] || video_data["description"],
          thumbnail_url: video_data[:thumbnail_url] || video_data["thumbnail_url"] || "https://img.youtube.com/vi/#{video_data[:video_id] || video_data['video_id']}/hqdefault.jpg",
          duration: video_data[:duration] || video_data["duration"],
          view_count: video_data[:view_count] || video_data["view_count"],
          published_at: video_data[:published_at] || video_data["published_at"],
          video_data: video_data,
          visible: visible,
          sort_order: index
        )
        created_videos << video
      end

      # Queue transcript processing for all created videos
      Rails.logger.info "🎬 Queuing transcript processing for #{created_videos.count} videos"
      created_videos.each do |video|
        video.queue_transcript_processing
      end

      # Return the saved videos with visibility information
      videos_with_visibility = @school.place.youtube_videos.ordered.map do |video|
        transcript_status = video.transcript_processing_status
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
          view_count_formatted: video.view_count_display,
          transcript_status: transcript_status,
          has_transcript: video.has_transcript?,
          can_retry_transcript: video.can_retry_transcript?,
          transcript_segments_count: video.transcript_segments_count
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
        format.json { render json: { success: false, message: "Video key is required." }, status: :bad_request }
      end
      return
    end

    # Find the video in the database
    video = @school.place.youtube_videos.find_by(video_id: params[:video_key])
    unless video
      respond_to do |format|
        format.json { render json: { success: false, message: "Video not found." }, status: :not_found }
      end
      return
    end

    # Toggle visibility
    new_visibility = !video.visible

    if video.update(visible: new_visibility)
      create_audit_log(@school, "update", [ "video_visibility" ])

      respond_to do |format|
        format.json {
          render json: {
            success: true,
            visible: new_visibility,
            message: new_visibility ? "Video is now visible." : "Video is now hidden."
          }
        }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, message: "Failed to update video visibility.", errors: video.errors.full_messages } }
      end
    end
  end

  def generate_transcript
    Rails.logger.info "🎬 Generate transcript request - Video: #{params[:video_key]}, School: #{params[:school_id]}, User: #{current_user&.email}"
    Rails.logger.info "🎬 All params: #{params.inspect}"

    begin
      @school = current_school
      Rails.logger.info "✅ School loaded: #{@school.name} (ID: #{@school.id})"

      unless params[:video_key].present?
        Rails.logger.warn "❌ No video key provided"
        respond_to do |format|
          format.json { render json: { success: false, message: "Video key is required." }, status: :bad_request }
        end
        return
      end

      # Find the video in the database
      Rails.logger.info "🔍 Looking for video: #{params[:video_key]} in school's YouTube videos"
      video = @school.place.youtube_videos.find_by(video_id: params[:video_key])
      unless video
        Rails.logger.warn "❌ Video not found: #{params[:video_key]}"
        respond_to do |format|
          format.json { render json: { success: false, message: "Video not found." }, status: :not_found }
        end
        return
      end

      Rails.logger.info "✅ Video found: #{video.title} - Status: #{video.transcript_status}"

      # Check if transcript is already processing or completed
      if video.transcript_status == "processing"
        Rails.logger.info "❌ Transcript already processing"
        respond_to do |format|
          format.json { render json: { success: false, message: "Transcript is already being processed." }, status: :bad_request }
        end
        return
      end

      if video.transcript_status == "completed"
        Rails.logger.info "❌ Transcript already completed"
        respond_to do |format|
          format.json { render json: { success: false, message: "Transcript already exists for this video." }, status: :bad_request }
        end
        return
      end

      # Allow retries for failed transcripts
      if video.transcript_status == "failed"
        Rails.logger.info "🔄 Retrying failed transcript for video: #{video.video_id}"
      else
        Rails.logger.info "🆕 Starting new transcript for video: #{video.video_id}"
      end

      # Queue transcript processing
      Rails.logger.info "🚀 Attempting to queue transcript processing for video: #{video.video_id}"
      result = video.queue_transcript_processing
      Rails.logger.info "📊 Queue result: #{result}"

      if result
        create_audit_log(@school, "create", [ "video_transcript" ])
        Rails.logger.info "✅ Transcript processing queued successfully"

        respond_to do |format|
          format.json {
            render json: {
              success: true,
              message: "Transcript generation started. This may take a few minutes."
            }
          }
        end
      else
        Rails.logger.warn "❌ Failed to queue transcript processing"
        respond_to do |format|
          format.json { render json: { success: false, message: "Failed to start transcript generation. Video may not have captions available." } }
        end
      end

    rescue => e
      Rails.logger.error "🚨 Generate transcript error for video #{params[:video_key]}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      respond_to do |format|
        format.json {
          render json: {
            success: false,
            message: "An error occurred while starting transcript generation. Please try again.",
            error_details: Rails.env.development? ? e.message : nil
          },
          status: :internal_server_error
        }
      end
    end
  end

  def toggle_transcript_ai
    Rails.logger.info "🔄 Toggle transcript AI request - Video: #{params[:video_key]}, School: #{params[:school_id]}"

    begin
      @school = current_school

      unless params[:video_key].present?
        Rails.logger.warn "❌ No video key provided"
        respond_to do |format|
          format.json { render json: { success: false, message: "Video key is required." }, status: :bad_request }
        end
        return
      end

      # Find the video and its transcript
      video = @school.place.youtube_videos.find_by(video_id: params[:video_key])
      unless video
        Rails.logger.warn "❌ Video not found: #{params[:video_key]}"
        respond_to do |format|
          format.json { render json: { success: false, message: "Video not found." }, status: :not_found }
        end
        return
      end

      transcript = video.transcript_record
      unless transcript&.completed?
        Rails.logger.warn "❌ No completed transcript found for: #{params[:video_key]}"
        respond_to do |format|
          format.json { render json: { success: false, message: "No completed transcript available." }, status: :bad_request }
        end
        return
      end

      # Toggle the AI enabled status
      new_status = !transcript.ai_enabled?
      transcript.update!(ai_enabled: new_status)

      action = new_status ? "enabled" : "disabled"
      Rails.logger.info "✅ Transcript AI #{action} for video: #{video.video_id}"

      # Create audit log
      create_audit_log(@school, "update", [ "transcript_ai_#{action}" ])

      # Return updated status
      updated_status = video.transcript_processing_status

      respond_to do |format|
        format.json {
          render json: {
            success: true,
            message: "Transcript #{action} for AI use.",
            ai_enabled: new_status,
            transcript_status: updated_status
          }
        }
      end

    rescue => e
      Rails.logger.error "🚨 Toggle transcript AI error for video #{params[:video_key]}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      respond_to do |format|
        format.json {
          render json: {
            success: false,
            message: "An error occurred while toggling transcript AI status. Please try again.",
            error_details: Rails.env.development? ? e.message : nil
          },
          status: :internal_server_error
        }
      end
    end
  end

  def import_website_data
    @school = current_school

    unless @school.website_url.present?
      respond_to do |format|
        format.json { render json: { success: false, message: "No website URL found for this school." }, status: :bad_request }
      end
      return
    end

    # Check if an import is already in progress
    if @school.website_crawling_status == "crawling"
      respond_to do |format|
        format.json { render json: { success: false, message: "Import already in progress." }, status: :bad_request }
      end
      return
    end

    # Queue the import job
    begin
      ImportSchoolWebsiteDataJob.perform_later(@school.id)

      # Update status to indicate import started
      @school.update!(
        website_crawling_status: "crawling",
        website_crawling_error: nil
      )

      create_audit_log(@school, "update", [ "website_crawling_status" ])

      respond_to do |format|
        format.json { render json: { success: true, message: "Website import started in background." } }
      end
    rescue => e
      Rails.logger.error "Failed to start website import for school #{@school.id}: #{e.message}"

      respond_to do |format|
        format.json { render json: { success: false, message: "Failed to start website import." }, status: :internal_server_error }
      end
    end
  end

  def import_status
    @school = current_school

    status = {
      status: @school.website_crawling_status || "none",
      last_crawled: @school.website_crawled_at,
      pages_found: @school.website_pages_found,
      error: @school.website_crawling_error
    }

    respond_to do |format|
      format.json { render json: status }
    end
  end

  def upload_document
    @school = current_school

    unless params[:document].present?
      respond_to do |format|
        format.json { render json: { success: false, errors: [ "No file provided" ] }, status: :bad_request }
      end
      return
    end

    # Extract file for checksum calculation before creating document
    uploaded_file = params[:document]

    begin
      # Calculate checksum for duplicate detection
      file_data = uploaded_file.read
      uploaded_file.rewind # Reset file pointer
      checksum = Digest::SHA256.hexdigest(file_data)

      # Check for duplicate
      if @school.place.duplicate_document_exists?(checksum)
        respond_to do |format|
          format.json {
            render json: {
              success: false,
              errors: [ "This file is already uploaded: Delete the existing file and try again if you want to replace it." ],
              duplicate: true
            }, status: :unprocessable_entity
          }
        end
        return
      end

      # Create document
      @document = @school.place.documents.build(
        filename: uploaded_file.original_filename,
        ai_enabled: true
      )
      @document.file.attach(uploaded_file)

      if @document.save
        create_audit_log(@school, "create", [ "document_upload" ])

        respond_to do |format|
          format.json {
            render json: {
              success: true,
              message: "Document uploaded successfully and is being processed.",
              document: document_json(@document)
            }
          }
        end
      else
        respond_to do |format|
          format.json {
            render json: {
              success: false,
              errors: @document.errors.full_messages
            }, status: :unprocessable_entity
          }
        end
      end

    rescue => e
      Rails.logger.error "Failed to upload document: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if Rails.env.development?

      respond_to do |format|
        format.json {
          render json: {
            success: false,
            errors: [ "Failed to upload document. Please try again." ]
          }, status: :internal_server_error
        }
      end
    end
  end

  def delete_document
    @school = current_school

    unless params[:document_id].present?
      respond_to do |format|
        format.json { render json: { success: false, errors: [ "Document ID required" ] }, status: :bad_request }
      end
      return
    end

    @document = @school.place.documents.find_by(id: params[:document_id])

    unless @document
      respond_to do |format|
        format.json { render json: { success: false, errors: [ "Document not found" ] }, status: :not_found }
      end
      return
    end

    document_filename = @document.filename

    if @document.destroy
      create_audit_log(@school, "delete", [ "document" ])

      respond_to do |format|
        format.json {
          render json: {
            success: true,
            message: "Document '#{document_filename}' deleted successfully."
          }
        }
      end
    else
      respond_to do |format|
        format.json {
          render json: {
            success: false,
            errors: [ "Failed to delete document" ]
          }, status: :internal_server_error
        }
      end
    end
  end

  def toggle_document_ai
    @school = current_school

    unless params[:document_id].present?
      respond_to do |format|
        format.json { render json: { success: false, errors: [ "Document ID required" ] }, status: :bad_request }
      end
      return
    end

    @document = @school.place.documents.find_by(id: params[:document_id])

    unless @document
      respond_to do |format|
        format.json { render json: { success: false, errors: [ "Document not found" ] }, status: :not_found }
      end
      return
    end

    new_ai_status = !@document.ai_enabled?

    if @document.update(ai_enabled: new_ai_status)
      # If AI was just enabled and document is processed but has no embedding, reprocess it
      if new_ai_status && @document.processing_completed? && !@document.has_embedding?
        @document.reprocess!
      end

      create_audit_log(@school, "update", [ "document_ai_settings" ])

      respond_to do |format|
        format.json {
          render json: {
            success: true,
            ai_enabled: new_ai_status,
            message: new_ai_status ? "AI processing enabled" : "AI processing disabled",
            document: document_json(@document)
          }
        }
      end
    else
      respond_to do |format|
        format.json {
          render json: {
            success: false,
            errors: @document.errors.full_messages
          }, status: :unprocessable_entity
        }
      end
    end
  end

  def reprocess_document
    @school = current_school

    unless params[:document_id].present?
      respond_to do |format|
        format.json { render json: { success: false, errors: [ "Document ID required" ] }, status: :bad_request }
      end
      return
    end

    @document = @school.place.documents.find_by(id: params[:document_id])

    unless @document
      respond_to do |format|
        format.json { render json: { success: false, errors: [ "Document not found" ] }, status: :not_found }
      end
      return
    end

    unless @document.can_reprocess?
      respond_to do |format|
        format.json {
          render json: {
            success: false,
            errors: [ "Document cannot be reprocessed in its current state" ]
          }, status: :unprocessable_entity
        }
      end
      return
    end

    if @document.reprocess!
      create_audit_log(@school, "update", [ "document_reprocess" ])

      respond_to do |format|
        format.json {
          render json: {
            success: true,
            message: "Document reprocessing started",
            document: document_json(@document)
          }
        }
      end
    else
      respond_to do |format|
        format.json {
          render json: {
            success: false,
            errors: [ "Failed to start reprocessing" ]
          }, status: :internal_server_error
        }
      end
    end
  end

  def download_document
    @school = current_school

    unless params[:document_id].present?
      respond_to do |format|
        format.json { render json: { success: false, errors: [ "Document ID required" ] }, status: :bad_request }
      end
      return
    end

    @document = @school.place.documents.find_by(id: params[:document_id])

    unless @document
      respond_to do |format|
        format.json { render json: { success: false, errors: [ "Document not found" ] }, status: :not_found }
        format.html { redirect_back(fallback_location: edit_school_owner_school_path(@school), alert: "Document not found") }
      end
      return
    end

    unless @document.file.attached?
      respond_to do |format|
        format.json { render json: { success: false, errors: [ "File not available" ] }, status: :not_found }
        format.html { redirect_back(fallback_location: edit_school_owner_school_path(@school), alert: "File not available") }
      end
      return
    end

    # Increment download counter
    @document.increment_download_count!
    create_audit_log(@school, "download", [ "document" ])

    # Redirect to the file
    respond_to do |format|
      format.json { render json: { success: true, download_url: @document.download_url } }
      format.html { redirect_to @document.download_url }
    end
  end

  private

  def handle_photo_uploads(photo_files)
    return false unless @school.place

    uploaded_count = 0

    photo_files.each_with_index do |photo_file, index|
      next if photo_file.blank?

      begin
        media_item = @school.place.media_items.create!(
          kind: "photo",
          source: "school_upload",
          alt_text: "#{@school.name} uploaded photo",
          sort_order: @school.place.media_items.photos.maximum(:sort_order).to_i + index + 1
        )

        media_item.file.attach(photo_file)
        uploaded_count += 1

        Rails.logger.info "Successfully uploaded photo for school #{@school.id}: #{photo_file.original_filename}"
      rescue => e
        Rails.logger.error "Failed to upload photo for school #{@school.id}: #{e.message}"
      end
    end

    uploaded_count > 0
  end

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
      :boarding, :school_bus, :language_support_notes, :tone_of_voice
    )
  end

  def all_school_params
    params.require(:school).permit(
      :name, :about, :website_url, :admissions_url, :phone, :email,
      :address_line_1, :address_line_2, :district, :province, :postcode, :country_code,
      :facebook_url, :line_id, :whatsapp_number, :youtube_url, :linkedin_url, :twitter_url, :instagram_url,
      :founded_year, :ownership, :avg_class_size, :student_teacher_ratio,
      :boarding, :school_bus, :language_support_notes, :tone_of_voice,
      curriculum: [], accreditation: [], language: [], program: [], facility: []
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

  def create_audit_log(school, action, changed_fields = nil)
    return unless defined?(AuditLog)

    # Determine what changes to record
    changes_hash = case changed_fields
    when Array
      # Convert field names to actual Rails changes (before/after values)
      if action == "update" && school.previous_changes.present?
        # Use previous_changes after a successful save
        school.previous_changes.slice(*changed_fields).except("updated_at", "created_at")
      elsif action == "update" && school.changes.present?
        # Use current changes if before save
        school.changes.slice(*changed_fields).except("updated_at", "created_at")
      else
        # For creates or when no changes available, create field => [nil, current_value] pairs
        changed_fields.each_with_object({}) do |field, hash|
          current_value = school.try(field)
          hash[field] = [ nil, current_value ]
        end
      end
    when Hash
      # Already a proper changes hash
      changed_fields.except("updated_at", "created_at")
    else
      # Default: use all model changes
      (school.previous_changes.presence || school.changes || {}).except("updated_at", "created_at")
    end

    # Only create audit log if there are actual changes or it's a significant action
    return if changes_hash.empty? && !%w[create delete].include?(action)

    AuditLog.create!(
      auditable: school,
      user_id: current_user.id,
      action: action,
      changed_fields: changes_hash
    )
  end

  def document_json(document)
    {
      id: document.id,
      filename: document.filename,
      original_filename: document.original_filename,
      file_type: document.file_type_display,
      file_size: document.file_size_display,
      processing_status: document.processing_status,
      processing_status_display: document.processing_status_display,
      ai_enabled: document.ai_enabled?,
      has_text: document.has_extracted_text?,
      has_embedding: document.has_embedding?,
      download_count: document.download_count,
      created_at: document.created_at,
      updated_at: document.updated_at,
      can_reprocess: document.can_reprocess?,
      text_preview: document.text_preview,
      download_url: document.download_url,
      preview_url: document.preview_url
    }
  end


  private

  def get_or_create_conversation
    @school.ai_conversations
           .where(user: current_user)
           .active
           .recent
           .first || create_new_conversation
  end

  def create_new_conversation
    @school.ai_conversations.create!(
      user: current_user,
      status: "active",
      title: "Chat #{Time.current.strftime('%b %d, %Y')}"
    )
  end

  def format_message(message)
    {
      id: message.id,
      role: message.role,
      content: message.content,
      message_type: message.message_type,
      created_at: message.created_at.iso8601,
      age_display: message.age_display,
      sources: message.formatted_sources,
      has_sources: message.has_sources?
    }
  end

  def chat_data
    {
      conversation: {
        id: @conversation.id,
        title: @conversation.title,
        status: @conversation.status,
        message_count: @conversation.message_count
      },
      messages: @messages.map { |msg| format_message(msg) },
      suggested_questions: @suggested_questions || [],
      school_summary: @school_summary,
      school: {
        id: @school.id,
        name: @school.name,
        completeness_score: calculate_completeness_score
      }
    }
  end

  def get_suggested_questions
    ai_service = AiChatService.new(@conversation)
    result = ai_service.generate_suggested_questions(limit: 4)
    result[:success] ? result[:questions] : default_suggested_questions
  rescue
    default_suggested_questions
  end

  def get_school_summary
    content_service = ContentRetrievalService.new(@school)
    content_service.generate_school_summary
  rescue => e
    Rails.logger.error "School Summary Error: #{e.message}"
    { error: "Unable to generate school summary" }
  end

  def calculate_completeness_score
    content_service = ContentRetrievalService.new(@school)
    summary = content_service.generate_school_summary
    summary[:completeness_score] || 0
  rescue => e
    Rails.logger.error "Completeness Score Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    0
  end

  def default_suggested_questions
    [
      {
        text: "Tell me about your facilities and campus features",
        metadata: { category: "facilities", priority: "high", source: "default" }
      },
      {
        text: "What is the tuition process for 5th grade students?",
        metadata: { category: "admissions", priority: "high", source: "default" }
      },
      {
        text: "Describe your curriculum and academic programs",
        metadata: { category: "academics", priority: "high", source: "default" }
      },
      {
        text: "How can I improve my school's profile completeness?",
        metadata: { category: "optimization", priority: "medium", source: "default" }
      }
    ]
  end
end
