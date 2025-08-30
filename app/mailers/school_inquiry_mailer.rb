class SchoolInquiryMailer < ApplicationMailer
  default from: 'noreply@7peakssoftware.com'

  def new_inquiry_notification(school_inquiry)
    @inquiry = school_inquiry
    @school = @inquiry.school
    
    # Recipients: school email if exists, plus benjamin@7peakssoftware.com
    recipients = ['benjamin@7peakssoftware.com']
    if @school.email.present?
      recipients << @school.email
    end
    
    mail(
      to: recipients.uniq,
      subject: "New inquiry for #{@school.name} from #{@inquiry.name}",
      reply_to: @inquiry.email
    )
  end
end
