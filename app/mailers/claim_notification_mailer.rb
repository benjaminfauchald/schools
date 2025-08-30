class ClaimNotificationMailer < ApplicationMailer
  default from: 'noreply@schoollistings.com'

  def claim_submitted(school_claim)
    @school_claim = school_claim
    @user = school_claim.user
    @school = school_claim.school
    
    # Generate magic link token for dashboard access
    @magic_token = MagicLinkToken.create_dashboard_token(@user)
    
    mail(
      to: @user.email,
      subject: "School Claim Submitted - #{@school.name}"
    )
  end

  def claim_approved(school_claim)
    @school_claim = school_claim
    @user = school_claim.user
    @school = school_claim.school
    
    # Generate magic link token for dashboard access
    @magic_token = MagicLinkToken.create_dashboard_token(@user)
    
    mail(
      to: @user.email,
      subject: "School Claim Approved - #{@school.name}"
    )
  end

  def claim_rejected(school_claim)
    @school_claim = school_claim
    @user = school_claim.user
    @school = school_claim.school
    
    mail(
      to: @user.email,
      subject: "School Claim Update - #{@school.name}"
    )
  end

  def claim_revoked(school_claim)
    @school_claim = school_claim
    @user = school_claim.user
    @school = school_claim.school
    
    mail(
      to: @user.email,
      subject: "School Access Revoked - #{@school.name}"
    )
  end

  # Notify admins of new claims
  def new_claim_for_admin(school_claim)
    @school_claim = school_claim
    @user = school_claim.user
    @school = school_claim.school
    
    # Send to all admin users
    admin_emails = User.admins.pluck(:email)
    return if admin_emails.empty?
    
    mail(
      to: admin_emails,
      subject: "New School Claim Requires Review - #{@school.name}"
    )
  end
end