class SchoolOwner::InquiriesController < SchoolOwner::ApplicationController
  before_action :set_inquiry, only: [:show, :update]
  
  def index
    @inquiries = SchoolInquiry.joins(:school)
                             .where(schools: { id: current_user.owned_schools.select(:id) })
                             .includes(:school, :user)
                             .recent
    
    # Filter by status if provided
    @inquiries = @inquiries.where(status: params[:status]) if params[:status].present?
    
    # Filter by school if provided
    @inquiries = @inquiries.where(school_id: params[:school_id]) if params[:school_id].present?
    
    @inquiries = @inquiries.page(params[:page])
    
    # For filter dropdowns
    @schools = current_user.owned_schools.order(:name)
    @statuses = SchoolInquiry.statuses.keys.map { |status| [status.humanize, status] }
  end
  
  def show
    @inquiry.mark_as_read!
  end
  
  def update
    if @inquiry.update(inquiry_params)
      redirect_to school_owner_inquiry_path(@inquiry), 
                  notice: 'Inquiry status updated successfully.'
    else
      render :show, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_inquiry
    @inquiry = SchoolInquiry.joins(:school)
                           .where(schools: { id: current_user.owned_schools.select(:id) })
                           .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to school_owner_inquiries_path, alert: 'Inquiry not found or access denied.'
  end
  
  def inquiry_params
    params.require(:school_inquiry).permit(:status)
  end
end