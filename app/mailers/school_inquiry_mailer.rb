class SchoolInquiryMailer < ApplicationMailer
  default from: 'noreply@7peakssoftware.com'

  def new_inquiry_notification(school_inquiry)
    @inquiry = school_inquiry
    @school = @inquiry.school
    
    # Recipients: school email if exists, school owners, plus benjamin@7peakssoftware.com
    recipients = ['benjamin@7peakssoftware.com']
    
    # Add school email if exists
    if @school.email.present?
      recipients << @school.email
    end
    
    # Add school owners (users with active claims)
    school_owner_emails = @school.school_claims.active.joins(:user).pluck('users.email')
    recipients.concat(school_owner_emails)
    
    mail(
      to: recipients.uniq,
      subject: "New inquiry for #{@school.name} from #{@inquiry.name}",
      reply_to: @inquiry.email
    )
  end
end
