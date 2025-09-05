class DirectClaimsController < ApplicationController
  before_action :set_school, only: [:new, :create]
  
  def new
    # Check if school is already claimed by current user (if signed in)
    if user_signed_in?
      existing_claim = current_user.school_claims.find_by(school: @school)
      if existing_claim&.approved?
        redirect_to school_owner_school_path(@school), 
                    notice: 'You already manage this school.'
        return
      elsif existing_claim&.pending?
        redirect_to school_owner_claims_path,
                    notice: 'You already have a pending claim for this school.'
        return
      end
    end
    
    @direct_claim = DirectClaimForm.new
  end
  
  def create
    @direct_claim = DirectClaimForm.new(direct_claim_params)
    
    # Validate the form
    unless @direct_claim.valid?
      render :new, status: :unprocessable_entity
      return
    end
    
    # Check if user is signed in and trying to claim with different email
    if user_signed_in? && current_user.email != @direct_claim.email
      @direct_claim.errors.add(:email, "must match your account email (#{current_user.email})")
      render :new, status: :unprocessable_entity
      return
    end
    
    # Process the claim using the service
    result = AutoClaimService.new(
      email: @direct_claim.email,
      school: @school,
      evidence_url: @direct_claim.evidence_url,
      notes: @direct_claim.notes,
      ip_address: request.remote_ip
    ).call
    
    if result[:success]
      respond_to do |format|
        format.html do
          # Store claim info for success page (fallback)
          session[:claim_result] = {
            school_name: @school.name,
            email: @direct_claim.email,
            created_user: result[:created_user],
            claim_id: result[:school_claim].id,
            message: result[:message]
          }
          
          redirect_to direct_claim_success_path
        end
        
        format.json do
          render json: {
            success: true,
            title: 'Claim Submitted Successfully!',
            message: result[:message],
            school_name: @school.name,
            school_url: school_path(id: @school.id),
            created_user: result[:created_user],
            claim_id: result[:school_claim].id
          }
        end
      end
    else
      respond_to do |format|
        format.html do
          @direct_claim.errors.add(:base, result[:message])
          render :new, status: :unprocessable_entity
        end
        
        format.json do
          render json: {
            success: false,
            errors: [@direct_claim.errors.full_messages, result[:message]].flatten.compact
          }, status: :unprocessable_entity
        end
      end
    end
  end
  
  def success
    @claim_result = session[:claim_result]
    
    if @claim_result.nil?
      redirect_to root_path, alert: 'Claim session expired.'
      return
    end
    
    # Clear the session data after displaying
    session.delete(:claim_result)
  end
  
  private
  
  def set_school
    @school = School.find(params[:school_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: 'School not found.'
  end
  
  def direct_claim_params
    params.require(:direct_claim).permit(:email, :evidence_url, :notes)
  rescue ActionController::ParameterMissing
    {}
  end
end