class SchoolOwner::SchoolsController < SchoolOwner::ApplicationController
  before_action :set_school, only: [:show, :edit, :update, :academic_programs, :update_academic_programs, :facilities, :update_facilities]
  
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
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @school.errors.full_messages } }
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
  
  private
  
  def set_school
    @school = current_school
  end
  
  def school_params
    params.require(:school).permit(
      :name, :about, :website_url, :admissions_url, :phone, :email,
      :address_line_1, :address_line_2, :district, :province, :postcode, :country_code,
      :facebook_url, :line_id, :whatsapp_number,
      :founded_year, :ownership, :avg_class_size, :student_teacher_ratio,
      :boarding, :school_bus, :language_support_notes,
      photos: []
    )
  end
  
  def all_school_params
    params.require(:school).permit(
      :name, :about, :website_url, :admissions_url, :phone, :email,
      :address_line_1, :address_line_2, :district, :province, :postcode, :country_code,
      :facebook_url, :line_id, :whatsapp_number,
      :founded_year, :ownership, :avg_class_size, :student_teacher_ratio,
      :boarding, :school_bus, :language_support_notes,
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
    
    taxonomy_params.each do |vocabulary_code, term_codes|
      next if term_codes.blank?
      
      # Remove existing taggings for this vocabulary
      vocabulary = Vocabulary.find_by(code: vocabulary_code.to_s)
      next unless vocabulary
      
      @school.taggings.joins(:term)
             .where(terms: { vocabulary_id: vocabulary.id })
             .destroy_all
      
      # Add new taggings
      term_codes.reject(&:blank?).each do |term_slug|
        term = vocabulary.terms.find_by(slug: term_slug)
        next unless term
        
        tagging = @school.taggings.build(
          term: term,
          tagger_id: current_user.id,
          tagger_type: 'User',
          context: vocabulary_code.to_s
        )
        
        unless tagging.save
          success = false
          Rails.logger.error "Failed to save tagging: #{tagging.errors.full_messages}"
        end
      end
    end
    
    success
  rescue => e
    Rails.logger.error "Error updating school taxonomy: #{e.message}"
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