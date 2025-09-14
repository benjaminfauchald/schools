class Schools::ContactFormComponent < ViewComponent::Base
  def initialize(school:, contact_info: {}, user_signed_in: false, facebook_authenticated: false, debug_mode: false, current_user: nil)
    @school = school
    @contact_info = contact_info
    @user_signed_in = user_signed_in
    @facebook_authenticated = facebook_authenticated
    @debug_mode = debug_mode
    @current_user = current_user
    @school_inquiry = build_school_inquiry
  end

  def render?
    school.present?
  end

  private

  attr_reader :school, :contact_info, :user_signed_in, :facebook_authenticated, :debug_mode, :school_inquiry, :current_user
  
  def build_school_inquiry
    inquiry = SchoolInquiry.new
    
    # Pre-fill form fields if user is signed in
    if current_user
      inquiry.name = current_user.facebook_name || current_user.email.split('@').first.humanize
      inquiry.email = current_user.email
      inquiry.phone = current_user.phone if current_user.respond_to?(:phone)
    end
    
    inquiry
  end
end
