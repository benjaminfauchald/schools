class SchoolOwner::ClaimsController < SchoolOwner::ApplicationController
  def index
    @claims = current_user.school_claims.includes(:school).order(created_at: :desc)
  end

  def show
    @claim = current_user.school_claims.find(params[:id])
  end

  def new
    @school = School.find(params[:school_id])
    @claim = current_user.school_claims.build(school: @school)

    # Check if user already has a claim for this school
    if current_user.school_claims.where(school: @school).exists?
      redirect_to school_owner_claims_path,
                  alert: "You already have a claim for this school."
      nil
    end
  end

  def create
    @school = School.find(params[:school_id])
    @claim = current_user.school_claims.build(claim_params.merge(school: @school))

    if @claim.save
      # Send notification email to admins
      notify_admins_of_new_claim(@claim)

      redirect_to school_owner_claim_path(@claim),
                  notice: "School claim submitted successfully. We will review it shortly."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def claim_params
    params.require(:school_claim).permit(:evidence_url, :notes)
  end

  def notify_admins_of_new_claim(claim)
    # TODO: Implement email notification to admins
    # AdminMailer.new_school_claim(claim).deliver_later
  end
end
