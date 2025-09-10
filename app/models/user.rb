class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable, :omniauthable

  # Associations
  has_many :school_claims, dependent: :destroy
  has_many :claimed_schools, through: :school_claims, source: :school
  has_many :audit_logs, dependent: :destroy
  has_many :magic_link_tokens, dependent: :destroy
  has_many :ai_conversations, dependent: :destroy
  has_many :school_inquiries, dependent: :destroy
  has_many :webhook_audit_logs, dependent: :destroy

  # Validations
  validates :role, inclusion: { in: %w[school_owner admin] }
  validates :email, presence: true, uniqueness: true
  validates :email, format: {
    without: /<|>/,
    message: "cannot contain HTML tags"
  }, if: :email_changed?
  validates :email, length: { maximum: 254 }, if: :email_changed?
  validates :provider, :uid, presence: true, if: -> { provider.present? || uid.present? }

  # Enums
  enum :role, {
    school_owner: "school_owner",
    admin: "admin"
  }

  # OmniAuth methods
  def self.from_omniauth(auth)
    # Sanitize input data to prevent XSS attacks - strip ALL HTML tags
    sanitized_name = ActionController::Base.helpers.strip_tags(auth.info.name.to_s)
    sanitized_email = ActionController::Base.helpers.strip_tags(auth.info.email.to_s).downcase.strip if auth.info.email.present?
    sanitized_uid = auth.uid.to_s.gsub(/[^a-zA-Z0-9_-]/, "") # Remove any non-alphanumeric chars from UID

    # Try to find existing user by provider and uid first
    user = User.find_by(provider: auth.provider, uid: sanitized_uid)

    if user
      # Update Facebook name and profile picture if they're different (sanitized)
      updates = {}
      updates[:facebook_name] = sanitized_name if user.facebook_name != sanitized_name
      updates[:facebook_profile_picture_url] = auth.info.image if user.facebook_profile_picture_url != auth.info.image
      user.update(updates) if updates.any?
      return user
    end

    # SECURITY FIX: Do NOT link OAuth to existing email accounts automatically
    # This prevents account takeover where attacker with same email but different UID
    # could take over an existing account
    if sanitized_email.present?
      existing_user = User.find_by(email: sanitized_email)

      if existing_user
        # If user exists with this email but different provider/uid, this is a security risk
        # Do NOT update their provider/uid - this would allow account takeover
        Rails.logger.warn "OAuth login attempt for existing email #{sanitized_email} with different provider/uid"

        # Return unpersisted user with error to trigger registration flow
        user = User.new(email: sanitized_email)
        user.errors.add(:email, "already exists. Please sign in with your existing account first, then link Facebook in settings.")
        return user
      end
    end

    # Handle missing email by generating a placeholder
    final_email = sanitized_email.presence || "fb_#{sanitized_uid}@facebook.local"

    # Create new user with sanitized data
    User.create!(
      email: final_email,
      provider: auth.provider,
      uid: sanitized_uid,
      facebook_name: sanitized_name,
      facebook_profile_picture_url: auth.info.image,
      role: "school_owner", # Default role for new Facebook users
      confirmed_at: Time.current, # Skip email confirmation for OAuth users
      password: Devise.friendly_token[0, 20] # Random password (won't be used)
    )
  end

  # Callbacks
  after_update :process_temp_claims_on_confirmation, if: :confirmed_at_changed?

  # Scopes
  scope :school_owners, -> { where(role: "school_owner") }
  scope :admins, -> { where(role: "admin") }

  # Role checking methods
  def school_owner?
    role == "school_owner"
  end

  def admin?
    role == "admin"
  end

  # School management methods
  def can_edit_school?(school)
    return true if admin?
    return false unless school_owner?

    active_claims.joins(:school).where(school: school).exists?
  end

  def approved_claims
    school_claims.where(status: "approved")
  end

  def active_claims
    school_claims.active
  end

  def pending_claims
    school_claims.where(status: "pending")
  end

  def owned_schools
    return School.all if admin?

    School.joins(:school_claims)
          .where(school_claims: { user: self, status: "approved", revoked_at: nil })
  end

  def display_name
    email.split("@").first.humanize
  end

  # Facebook OAuth helper methods
  def facebook_user?
    provider == "facebook" && uid.present?
  end

  def facebook_authenticated?
    facebook_user? && uid.present?
  end

  def facebook_display_name
    facebook_name.present? ? facebook_name : display_name
  end

  def profile_picture_url
    facebook_profile_picture_url
  end

  # Facebook webhook methods
  def delete_facebook_data!
    Rails.logger.info "Deleting Facebook data for user #{id} (#{email})"

    # Remove Facebook OAuth data while preserving the user account
    # This allows the user to still exist for business purposes (school ownership, inquiries)
    # but removes their ability to authenticate via Facebook
    update!(
      provider: nil,
      uid: nil,
      facebook_name: nil,
      facebook_profile_picture_url: nil
    )

    Rails.logger.info "Successfully deleted Facebook data for user #{id}"
  end

  def deauthorize_facebook!
    Rails.logger.info "Deauthorizing Facebook for user #{id} (#{email})"

    # Similar to delete_facebook_data! but could have different business logic
    # For now, we'll implement the same behavior - remove OAuth capability
    # but preserve user account and business relationships
    update!(
      provider: nil,
      uid: nil,
      facebook_name: nil,
      facebook_profile_picture_url: nil
    )

    Rails.logger.info "Successfully deauthorized Facebook for user #{id}"
  end

  def facebook_webhook_deletable?
    # Determine if user's Facebook data can be safely deleted
    # Always return true since we only delete OAuth data, not the user account
    facebook_user?
  end

  # Get Facebook profile picture URL with fallback
  def profile_picture_url
    if facebook_user? && facebook_profile_picture_url.present?
      facebook_profile_picture_url
    else
      nil # Could add a default avatar URL here if desired
    end
  end

  # Get display name preferring Facebook name
  def facebook_display_name
    if facebook_user? && facebook_name.present?
      facebook_name
    else
      display_name
    end
  end

  # Process temp claim after registration
  def process_temp_claim!(temp_claim_token)
    temp_claim = TempClaim.find_by(token: temp_claim_token)
    return false unless temp_claim&.active? && temp_claim.email == self.email

    # Create actual school claim from temp claim
    school_claim = school_claims.build(
      school: temp_claim.school,
      evidence_url: temp_claim.evidence_url,
      status: "pending"
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
          status: "pending"
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
