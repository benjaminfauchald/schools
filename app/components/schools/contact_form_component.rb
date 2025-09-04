class Schools::ContactFormComponent < ViewComponent::Base
  def initialize(school:, contact_info: {}, user_signed_in: false, facebook_authenticated: false, debug_mode: false)
    @school = school
    @contact_info = contact_info
    @user_signed_in = user_signed_in
    @facebook_authenticated = facebook_authenticated
    @debug_mode = debug_mode
    @school_inquiry = SchoolInquiry.new
  end

  private

  attr_reader :school, :contact_info, :user_signed_in, :facebook_authenticated, :debug_mode, :school_inquiry

  def render?
    school.present?
  end
end