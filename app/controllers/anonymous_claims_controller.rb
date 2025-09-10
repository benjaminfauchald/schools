class AnonymousClaimsController < ApplicationController
  # SECURITY FIX: This controller should NOT allow anonymous claims
  # Redirect all anonymous users to sign in
  before_action :require_authentication_for_claims!
  before_action :set_school, only: [ :new, :create ]
  before_action :set_temp_claim, only: [ :show, :complete_registration ]

  def new
    # This should never be reached by anonymous users
    # If user is authenticated, redirect to proper claims flow
    redirect_to new_direct_claim_path(school_id: @school.id),
                notice: "Please use the authenticated claims process."
  end

  def create
    # This should never be reached by anonymous users
    # Block any attempt to create claims without authentication
    redirect_to new_user_session_path,
                alert: "You must sign in to claim a school. Anonymous claims are not permitted."
  end

  def show
    # SECURITY: Block access to temp claims
    redirect_to new_user_session_path,
                alert: "You must sign in to access claims. Anonymous claims are not permitted."
  end

  def complete_registration
    # SECURITY: Block anonymous registration attempts
    redirect_to new_user_session_path,
                alert: "You must sign in to complete registration. Anonymous claims are not permitted."
  end

  private

  def set_school
    @school = School.find(params[:school_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "School not found."
  end

  def set_temp_claim
    @temp_claim = TempClaim.find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Invalid or expired claim link."
  end

  def temp_claim_params
    params.require(:temp_claim).permit(:email, :evidence_url, :notes)
  end

  def require_authentication_for_claims!
    # SECURITY: Always require authentication for ANY claim action
    unless user_signed_in?
      redirect_to new_user_session_path,
                  alert: "You must sign in to claim a school. School claims require authentication for security."
      nil
    end
  end
end
