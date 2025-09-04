module Admin
  class SchoolsController < Admin::ApplicationController

    def index
      search_term = params[:search]
      
      @schools = School.includes(:place, :school_claims)
      
      # Apply search filter
      if search_term.present?
        @schools = @schools.where(
          "name ILIKE ? OR district ILIKE ? OR province ILIKE ?", 
          "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
        )
      end
      
      # Apply ownership filter
      if params[:ownership].present?
        @schools = @schools.where(ownership: params[:ownership])
      end
      
      # Apply status filter
      if params[:status].present?
        @schools = @schools.where(status: params[:status])
      end
      
      @schools = @schools.order(:name).limit(50)
      
      # Statistics
      @total_schools = School.count
      @claimed_schools = School.joins(:school_claims).where(school_claims: { status: 'approved' }).distinct.count
      @public_schools = School.where(ownership: 'public').count
      @private_schools = School.where(ownership: 'private').count
      @active_schools = School.where(status: 'active').count
    end

    def show
      @school = School.includes(
        :place, :school_claims, :media_items, :events, 
        :school_fee_schedules, :school_grade_offering,
        :current_taggings, :current_terms
      ).find(params[:id])
      
      @recent_claims = @school.school_claims.includes(:user).order(created_at: :desc).limit(5)
      @approved_claims = @school.school_claims.where(status: 'approved')
      @pending_claims = @school.school_claims.where(status: 'pending')
    end

    def new
      @school = School.new
    end

    def create
      @school = School.new(school_params)
      
      if @school.save
        # Create audit log for the creation
        create_audit_log(@school, 'admin_create', school_params.keys)
        redirect_to admin_school_path(@school), notice: 'School was successfully created.'
      else
        render :new
      end
    end

    def edit
      @school = School.find(params[:id])
    end

    def update
      @school = School.find(params[:id])
      
      if @school.update(school_params)
        # Create audit log for the update
        create_audit_log(@school, 'admin_update', @school.previous_changes.keys - ['updated_at'])
        redirect_to admin_school_path(@school), notice: 'School was successfully updated.'
      else
        render :edit
      end
    end

    def destroy
      @school = School.find(params[:id])
      
      if @school.school_claims.any?
        redirect_to admin_schools_path, alert: 'Cannot delete school with existing claims.'
      else
        # Create audit log before deletion (capture school data before destruction)
        create_audit_log(@school, 'admin_delete', { name: [@school.name, nil], id: [@school.id, nil] })
        @school.destroy
        redirect_to admin_schools_path, notice: 'School was successfully deleted.'
      end
    end

    private

    def create_audit_log(school, action, changed_fields = nil)
      # Capture actual changes with before/after values
      changes_hash = case changed_fields
      when Array
        if action.include?('update') && school.previous_changes.present?
          # Get the actual Rails changes for specified fields
          school.previous_changes.slice(*changed_fields).except('updated_at', 'created_at')
        else
          # For non-update actions, create a simple hash
          changed_fields.present? ? { updated_fields: changed_fields } : {}
        end
      when Hash
        # Already a proper changes hash
        changed_fields
      when nil
        # Use all changes from the model
        school.previous_changes&.except('updated_at', 'created_at') || {}
      else
        { updated_fields: changed_fields }
      end

      AuditLog.create!(
        auditable: school,
        user_id: current_user&.id,
        action: action,
        changed_fields: changes_hash
      )
    rescue StandardError => e
      Rails.logger.error "Failed to create audit log: #{e.message}"
      # Don't fail the main action if audit logging fails
    end

    def school_params
      params.require(:school).permit(
        :name, :slug, :about, :ownership, :status,
        :address_line_1, :address_line_2, :district, :province, :postcode, :country_code,
        :phone, :email, :website_url, :facebook_url, :line_id, :whatsapp_number,
        :admissions_url, :founded_year, :avg_class_size, :student_teacher_ratio,
        :boarding, :school_bus, :language_support_notes
      )
    end
  end
end
