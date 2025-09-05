# SchoolClaim model manages user requests for administrative rights over school profiles
# Implements ownership verification workflow with evidence submission and admin approval
class SchoolClaim < ApplicationRecord
  belongs_to :school
  belongs_to :user
  
  validates :school_id, uniqueness: { scope: :user_id, message: 'already has a pending or approved claim' }
  validates :status, inclusion: { in: %w[pending approved rejected revoked] }
  validates :evidence_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true
  validates :notes, length: { maximum: 1000 }, allow_blank: true
  
  enum :status, {
    pending: 'pending',
    approved: 'approved', 
    rejected: 'rejected',
    revoked: 'revoked'
  }
  
  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: 'approved', revoked_at: nil) }
  scope :revoked, -> { where.not(revoked_at: nil) }
  
  # Callbacks
  after_create :send_submission_notifications
  
  # Approve the claim and grant school admin role
  def approve!(admin_user, notes: nil)
    transaction do
      update!(
        status: 'approved',
        admin_notes: notes,
        updated_at: Time.current
      )
      
      # TODO: Grant school_admin role when User/Role system exists
      # user.add_role(:school_admin, school)
      
      # Log the approval
      create_audit_log(admin_user, 'approve', notes)
      
      # Send notification email
      ClaimNotificationMailer.claim_approved(self).deliver_later
    end
  end
  
  # Reject the claim with reason
  def reject!(admin_user, notes:)
    transaction do
      update!(
        status: 'rejected',
        admin_notes: notes,
        updated_at: Time.current
      )
      
      # Log the rejection
      create_audit_log(admin_user, 'reject', notes)
      
      # Send notification email
      ClaimNotificationMailer.claim_rejected(self).deliver_later
    end
  end
  
  # Check if claim can be approved
  def can_approve?
    pending?
  end
  
  # Check if claim can be rejected
  def can_reject?
    pending?
  end
  
  # Revoke an approved claim
  def revoke!(admin_user, reason:)
    return false unless can_revoke?
    
    transaction do
      update!(
        status: 'revoked',
        revoked_at: Time.current,
        revoked_by_id: admin_user.id,
        revocation_reason: reason
      )
      
      # TODO: Remove school_admin role when User/Role system exists
      # user.remove_role(:school_admin, school)
      
      # Log the revocation
      create_audit_log(admin_user, 'revoke', reason)
      
      # Send notification email
      ClaimNotificationMailer.claim_revoked(self).deliver_later
    end
  end
  
  # Check if claim can be revoked
  def can_revoke?
    approved? && revoked_at.nil?
  end
  
  # Days since claim was submitted
  def days_pending
    return 0 unless pending?
    (Time.current - created_at) / 1.day
  end
  
  # Check if claim is stale (pending for over 30 days)
  def stale?
    pending? && days_pending > 30
  end
  
  # Get user email for admin display
  def user_email
    user&.email
  end
  
  # Check if claim is currently active (approved and not revoked)
  def active?
    approved? && revoked_at.nil?
  end
  
  # Get revoked by admin user (if revoked)
  def revoked_by
    return nil unless revoked_by_id
    # TODO: Replace with actual User model lookup when available
    # User.find_by(id: revoked_by_id)
    "Admin ID: #{revoked_by_id}"
  end
  
  private
  
  def send_submission_notifications
    # Send confirmation email to user
    ClaimNotificationMailer.claim_submitted(self).deliver_later
    
    # Send notification to admins
    ClaimNotificationMailer.new_claim_for_admin(self).deliver_later
  end
  
  def create_audit_log(admin_user, action, notes)
    # TODO: Create audit log when AuditLog model is available
    # AuditLog.create!(
    #   auditable: self,
    #   user: admin_user,
    #   action: action,
    #   changed_fields: { status: status, admin_notes: notes }
    # )
  end
end