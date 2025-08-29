class AnonymousClaimsController < ApplicationController
  before_action :set_school, only: [:new, :create]
  before_action :set_temp_claim, only: [:show, :complete_registration]
  before_action :ensure_not_signed_in, only: [:new, :create]
  
  def new
    # Check if school is already claimed
    if @school.claimed?
      redirect_to school_path(@school), alert: 'This school has already been claimed.'
      return
    end
    
    # Check for existing active temp claim for this school and IP
    existing_claim = TempClaim.active.find_by(school: @school, ip_address: request.remote_ip)
    if existing_claim
      redirect_to anonymous_claim_path(existing_claim.token), 
                  notice: 'You already have a pending claim for this school.'
      return
    end
    
    @temp_claim = TempClaim.new
  end
  
  def create
    @temp_claim = TempClaim.new(temp_claim_params)
    @temp_claim.school = @school
    @temp_claim.ip_address = request.remote_ip
    
    if @temp_claim.save
      session[:temp_claim_token] = @temp_claim.token
      redirect_to anonymous_claim_path(@temp_claim.token), 
                  notice: 'Claim submitted! Please complete your registration to continue.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def show
    if @temp_claim.expired?
      redirect_to root_path, alert: 'This claim has expired. Please submit a new claim.'
      return
    end
    
    if @temp_claim.registered?
      redirect_to new_user_session_path, notice: 'Please sign in to continue with your claim.'
      return
    end
  end
  
  def complete_registration
    if @temp_claim.expired?
      redirect_to root_path, alert: 'This claim has expired. Please submit a new claim.'
      return
    end
    
    if @temp_claim.registered?
      redirect_to new_user_session_path, notice: 'Please sign in to continue with your claim.'
      return
    end
    
    # Store temp claim token in session for registration process
    session[:temp_claim_token] = @temp_claim.token
    redirect_to new_user_registration_path
  end
  
  private
  
  def set_school
    @school = School.find(params[:school_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: 'School not found.'
  end
  
  def set_temp_claim
    @temp_claim = TempClaim.find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: 'Invalid or expired claim link.'
  end
  
  def temp_claim_params
    params.require(:temp_claim).permit(:email, :evidence_url, :notes)
  end
  
  def ensure_not_signed_in
    if user_signed_in?
      redirect_to new_school_owner_claim_path(school_id: @school.id), 
                  notice: 'Please use the regular claiming process since you are already signed in.'
    end
  end
end