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
        @school.destroy
        redirect_to admin_schools_path, notice: 'School was successfully deleted.'
      end
    end

    private

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
