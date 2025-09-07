module Admin
  class InquiriesController < Admin::ApplicationController
    before_action :set_inquiry, only: [ :show, :update ]

    def index
      @inquiries = SchoolInquiry.includes(:school, :user).recent

      # Filter by status if provided
      @inquiries = @inquiries.where(status: params[:status]) if params[:status].present?

      # Filter by school if provided
      @inquiries = @inquiries.where(school_id: params[:school_id]) if params[:school_id].present?

      @inquiries = @inquiries.limit(50)

      # For filter dropdowns
      if params[:status].present?
        # If a status is selected, only show schools that have inquiries with that status
        school_ids_with_status = SchoolInquiry.where(status: params[:status]).distinct.pluck(:school_id)
        @schools = School.where(id: school_ids_with_status).order(:name)
      else
        # Show all schools that have any inquiries
        school_ids_with_inquiries = SchoolInquiry.distinct.pluck(:school_id)
        @schools = School.where(id: school_ids_with_inquiries).order(:name)
      end

      @statuses = SchoolInquiry.statuses.keys.map { |status| [ status.humanize, status ] }
    end

    def show
      # IMPORTANT: Admin viewing does NOT change the status - that's for school owners only
      # Do not call @inquiry.mark_as_read! here
    end

    def update
      if @inquiry.update(inquiry_params)
        redirect_to admin_inquiry_path(@inquiry),
                    notice: "Inquiry status updated successfully."
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def set_inquiry
      @inquiry = SchoolInquiry.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_inquiries_path, alert: "Inquiry not found."
    end

    def inquiry_params
      params.require(:school_inquiry).permit(:status)
    end
  end
end
