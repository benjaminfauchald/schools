class SchoolInquiriesController < ApplicationController
  before_action :set_school
  
  def create
    @inquiry = @school.school_inquiries.build(inquiry_params)
    @inquiry.ip_address = request.remote_ip
    
    if @inquiry.save
      # Send email notifications
      SchoolInquiryMailer.new_inquiry_notification(@inquiry).deliver_now
      
      render json: { 
        success: true, 
        message: 'Your inquiry has been sent successfully. The school will contact you soon!' 
      }
    else
      render json: { 
        success: false, 
        errors: @inquiry.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_school
    @school = School.find(params[:school_id])
  end
  
  def inquiry_params
    params.require(:school_inquiry).permit(:name, :email, :phone, :message, :children_count)
  end
end