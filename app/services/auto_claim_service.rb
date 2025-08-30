class AutoClaimService
  attr_reader :email, :school, :evidence_url, :notes, :ip_address
  
  def initialize(email:, school:, evidence_url: nil, notes: nil, ip_address: nil)
    @email = email
    @school = school
    @evidence_url = evidence_url
    @notes = notes
    @ip_address = ip_address
  end
  
  def call
    ActiveRecord::Base.transaction do
      user = find_or_create_user
      create_school_claim(user)
      
      {
        success: true,
        user: user,
        school_claim: @school_claim,
        created_user: @created_user,
        message: success_message
      }
    end
  rescue => e
    {
      success: false,
      error: e.message,
      message: "Unable to process claim: #{e.message}"
    }
  end
  
  private
  
  def find_or_create_user
    user = User.find_by(email: email)
    
    if user
      @created_user = false
      user
    else
      @created_user = true
      # Create user with temporary password - they'll set real password on confirmation
      temp_password = SecureRandom.urlsafe_base64(12)
      
      User.create!(
        email: email,
        password: temp_password,
        password_confirmation: temp_password,
        role: 'school_owner'
        # Don't set confirmed_at - user needs to verify email
      )
    end
  end
  
  def create_school_claim(user)
    # Check for existing claim
    existing_claim = user.school_claims.find_by(school: school)
    
    if existing_claim
      if existing_claim.pending?
        raise "You already have a pending claim for #{school.name}"
      elsif existing_claim.approved?
        raise "You already manage #{school.name}"
      elsif existing_claim.rejected?
        # Allow re-claiming after rejection with updated info
        existing_claim.update!(
          evidence_url: evidence_url,
          status: 'pending',
          admin_notes: nil, # Clear previous rejection notes
          updated_at: Time.current
        )
        @school_claim = existing_claim
      end
    else
      @school_claim = user.school_claims.create!(
        school: school,
        evidence_url: evidence_url,
        status: 'pending'
      )
    end
    
    # Store user notes in a separate field or system (for now, we'll add this info to audit logs)
    create_claim_notes(user) if notes.present?
  end
  
  def create_claim_notes(user)
    # TODO: When audit system is available, log the user's notes
    # For now, we could store in admin_notes temporarily or create a separate notes system
    Rails.logger.info "Claim notes for #{user.email} on #{school.name}: #{notes}"
  end
  
  def success_message
    if @created_user
      "Account created and claim submitted! Please check your email to verify your account."
    else
      user = User.find_by(email: email)
      if user.confirmed?
        "Additional claim submitted! You'll receive email updates when it's reviewed."
      else
        "Additional claim submitted! Please check your email to verify your account."
      end
    end
  end
end