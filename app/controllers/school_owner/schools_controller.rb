class SchoolOwner::SchoolsController < SchoolOwner::ApplicationController
  before_action :set_school, only: [:show, :edit, :update]
  
  def index
    @schools = current_user.owned_schools.includes(:place)
  end
  
  def show
    @school = current_school
  end
  
  def edit
    @school = current_school
  end
  
  def update
    @school = current_school
    
    if @school.update(school_params)
      # Log the update
      create_audit_log(@school, 'update', school_params.keys)
      
      redirect_to school_owner_school_path(@school), 
                  notice: 'School information updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_school
    @school = current_school
  end
  
  def school_params
    params.require(:school).permit(
      :name, :description, :website_url, :phone, :email,
      :address_line_1, :address_line_2, :district, :province, :postcode,
      :facebook_url, :line_id, :whatsapp_number,
      :student_count, :teacher_count, :established_year,
      :boarding, :school_bus, :uniform_required,
      :ownership, :country_code
    )
  end
  
  def create_audit_log(school, action, changed_fields)
    return unless defined?(AuditLog)
    
    AuditLog.create!(
      auditable: school,
      user: current_user,
      action: action,
      changed_fields: { updated_fields: changed_fields }
    )
  end
end