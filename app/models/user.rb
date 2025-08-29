class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  # Associations
  has_many :school_claims, dependent: :destroy
  has_many :claimed_schools, through: :school_claims, source: :school
  has_many :audit_logs, dependent: :destroy
  has_many :magic_link_tokens, dependent: :destroy

  # Validations
  validates :role, inclusion: { in: %w[school_owner admin] }
  validates :email, presence: true, uniqueness: true

  # Enums
  enum :role, {
    school_owner: 'school_owner',
    admin: 'admin'
  }

  # Callbacks
  after_update :process_temp_claims_on_confirmation, if: :confirmed_at_changed?

  # Scopes
  scope :school_owners, -> { where(role: 'school_owner') }
  scope :admins, -> { where(role: 'admin') }

  # Role checking methods
  def school_owner?
    role == 'school_owner'
  end

  def admin?
    role == 'admin'
  end

  # School management methods
  def can_edit_school?(school)
    return true if admin?
    return false unless school_owner?
    
    approved_claims.joins(:school).where(school: school).exists?
  end

  def approved_claims
    school_claims.where(status: 'approved')
  end

  def pending_claims
    school_claims.where(status: 'pending')
  end

  def owned_schools
    return School.all if admin?
    
    School.joins(:school_claims)
          .where(school_claims: { user: self, status: 'approved' })
  end

  def display_name
    email.split('@').first.humanize
  end

  # Process temp claim after registration
  def process_temp_claim!(temp_claim_token)
    temp_claim = TempClaim.find_by(token: temp_claim_token)
    return false unless temp_claim&.active? && temp_claim.email == self.email

    # Create actual school claim from temp claim
    school_claim = school_claims.build(
      school: temp_claim.school,
      evidence_url: temp_claim.evidence_url,
      status: 'pending'
    )
    
    # Note: admin_notes is for admin use, user notes from temp_claim are not transferred
    # The temp_claim.notes contained user's explanation which is now part of claim history

    if school_claim.save
      temp_claim.mark_as_registered!
      true
    else
      false
    end
  end

  private

  # Process all pending temp claims when user confirms email
  def process_temp_claims_on_confirmation
    return unless confirmed_at_previously_changed?(from: nil) # Only on first confirmation

    Rails.logger.info "Processing temp claims for newly confirmed user: #{email}"
    
    # Find all active temp claims for this user's email
    temp_claims = TempClaim.active.where(email: email)
    
    temp_claims.find_each do |temp_claim|
      Rails.logger.info "Processing temp claim #{temp_claim.token} for school #{temp_claim.school.name}"
      
      # Check if we already have a claim for this school
      existing_claim = school_claims.find_by(school: temp_claim.school)
      
      if existing_claim
        Rails.logger.info "School claim already exists, marking temp claim as registered"
        temp_claim.mark_as_registered!
      else
        # Create new school claim from temp claim
        school_claim = school_claims.build(
          school: temp_claim.school,
          evidence_url: temp_claim.evidence_url,
          status: 'pending'
        )
        
        if school_claim.save
          Rails.logger.info "Created school claim from temp claim"
          temp_claim.mark_as_registered!
        else
          Rails.logger.error "Failed to create school claim: #{school_claim.errors.full_messages}"
        end
      end
    end
    
    Rails.logger.info "Completed processing temp claims for user: #{email}"
  end
end
