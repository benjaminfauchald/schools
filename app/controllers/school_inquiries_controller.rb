class SchoolInquiriesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_facebook_authentication!
  before_action :set_school

  def create
    @inquiry = @school.school_inquiries.build(inquiry_params)
    @inquiry.ip_address = request.remote_ip
    @inquiry.user = current_user

    if @inquiry.save
      # Send email notifications
      begin
        SchoolInquiryMailer.new_inquiry_notification(@inquiry).deliver_now
      rescue => e
        Rails.logger.error "Failed to send inquiry email: #{e.message}"
      end

      render json: {
        success: true,
        message: "Your inquiry has been sent successfully. The school will contact you soon!"
      }
    else
      Rails.logger.error "School inquiry validation failed: #{@inquiry.errors.full_messages}"
      render json: {
        success: false,
        errors: @inquiry.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "School inquiry creation error: #{e.message}"
    render json: {
      success: false,
      errors: [ "An unexpected error occurred. Please try again." ]
    }, status: :internal_server_error
  end

  private

  def set_school
    @school = School.find(params[:school_id])
  end

  def inquiry_params
    params.require(:school_inquiry).permit(:name, :email, :phone, :message, :children_count)
  end

  def require_facebook_authentication!
    unless current_user&.provider == "facebook"
      render json: {
        success: false,
        errors: [ "You must sign in with Facebook to contact schools." ],
        requires_facebook_auth: true
      }, status: :forbidden
    end
  end
end
