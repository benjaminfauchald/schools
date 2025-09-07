module Admin
  class SchoolClaimsController < Admin::ApplicationController
    before_action :find_school_claim, only: [ :show ]

    def index
      search_term = params[:search]

      @school_claims = SchoolClaim.includes(:school, :user).order(created_at: :desc)

      # Apply search filter
      if search_term.present?
        @school_claims = @school_claims.joins(:school, :user).where(
          "schools.name ILIKE ? OR users.email ILIKE ? OR school_claims.admin_notes ILIKE ?",
          "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
        )
      end

      # Apply status filter
      if params[:status].present?
        @school_claims = @school_claims.where(status: params[:status])
      end

      # Apply date filter
      if params[:date_filter].present?
        case params[:date_filter]
        when "today"
          @school_claims = @school_claims.where(created_at: Date.current.beginning_of_day..Date.current.end_of_day)
        when "week"
          @school_claims = @school_claims.where(created_at: 1.week.ago..Time.current)
        when "month"
          @school_claims = @school_claims.where(created_at: 1.month.ago..Time.current)
        end
      end

      @school_claims = @school_claims.limit(50)

      # Statistics
      @total_claims = SchoolClaim.count
      @pending_claims = SchoolClaim.pending.count
      @approved_claims = SchoolClaim.approved.count
      @rejected_claims = SchoolClaim.rejected.count
      @today_claims = SchoolClaim.where(created_at: Date.current.beginning_of_day..Date.current.end_of_day).count
      @week_claims = SchoolClaim.where(created_at: 1.week.ago..Time.current).count

      # Status breakdown
      @status_counts = SchoolClaim.group(:status).count

      # Available statuses for filter
      @available_statuses = SchoolClaim.distinct.pluck(:status).compact.sort
    end

    def show
      # @school_claim is set by before_action
    end

    def new
      @school_claim = SchoolClaim.new
      @schools = School.order(:name).limit(100)
      @users = User.order(:email).limit(100)
    end

    def create
      @school_claim = SchoolClaim.new(school_claim_params)

      if @school_claim.save
        redirect_to admin_school_claim_path(@school_claim), notice: "School claim was successfully created."
      else
        @schools = School.order(:name).limit(100)
        @users = User.order(:email).limit(100)
        render :new
      end
    end

    def edit
      @school_claim = find_resource(params[:id])
      @schools = School.order(:name).limit(100)
      @users = User.order(:email).limit(100)
    end

    def update
      @school_claim = find_resource(params[:id])

      if @school_claim.update(school_claim_params)
        redirect_to admin_school_claim_path(@school_claim), notice: "School claim was successfully updated."
      else
        @schools = School.order(:name).limit(100)
        @users = User.order(:email).limit(100)
        render :edit
      end
    end

    def destroy
      @school_claim = find_resource(params[:id])
      @school_claim.destroy
      redirect_to admin_school_claims_path, notice: "School claim was successfully deleted."
    end

    def approve
      claim = requested_resource

      if claim.can_approve?
        claim.approve!(current_admin_user, notes: params[:admin_notes])
        redirect_to admin_school_claim_path(claim),
                    notice: "School claim approved successfully. User can now manage the school."
      else
        redirect_to admin_school_claim_path(claim),
                    alert: "Cannot approve this claim. It may already be processed."
      end
    end

    def reject
      claim = requested_resource

      if claim.can_reject?
        claim.reject!(current_admin_user, notes: params[:admin_notes] || "Claim rejected by admin")
        redirect_to admin_school_claim_path(claim),
                    notice: "School claim rejected."
      else
        redirect_to admin_school_claim_path(claim),
                    alert: "Cannot reject this claim. It may already be processed."
      end
    end

    def bulk_approve
      claim_ids = params[:claim_ids] || []
      admin_notes = params[:admin_notes] || "Bulk approved by admin"

      if claim_ids.empty?
        redirect_back(fallback_location: admin_school_claims_path, alert: "No claims selected for approval.")
        return
      end

      claims = SchoolClaim.where(id: claim_ids).pending
      approved_count = 0
      errors = []

      claims.each do |claim|
        if claim.can_approve?
          begin
            claim.approve!(current_admin_user, notes: admin_notes)
            approved_count += 1
          rescue => e
            errors << "Failed to approve claim for #{claim.school.name}: #{e.message}"
          end
        else
          errors << "Cannot approve claim for #{claim.school.name}: already processed"
        end
      end

      if approved_count > 0
        notice = "Successfully approved #{approved_count} claim#{'s' if approved_count != 1}."
      else
        notice = nil
      end

      if errors.any?
        alert = "Some claims could not be processed: #{errors.join(', ')}"
      else
        alert = nil
      end

      redirect_back(fallback_location: admin_school_claims_path, notice: notice, alert: alert)
    end

    def bulk_reject
      claim_ids = params[:claim_ids] || []
      admin_notes = params[:admin_notes] || "Bulk rejected by admin"

      if claim_ids.empty?
        redirect_back(fallback_location: admin_school_claims_path, alert: "No claims selected for rejection.")
        return
      end

      claims = SchoolClaim.where(id: claim_ids).pending
      rejected_count = 0
      errors = []

      claims.each do |claim|
        if claim.can_reject?
          begin
            claim.reject!(current_admin_user, notes: admin_notes)
            rejected_count += 1
          rescue => e
            errors << "Failed to reject claim for #{claim.school.name}: #{e.message}"
          end
        else
          errors << "Cannot reject claim for #{claim.school.name}: already processed"
        end
      end

      if rejected_count > 0
        notice = "Successfully rejected #{rejected_count} claim#{'s' if rejected_count != 1}."
      else
        notice = nil
      end

      if errors.any?
        alert = "Some claims could not be processed: #{errors.join(', ')}"
      else
        alert = nil
      end

      redirect_back(fallback_location: admin_school_claims_path, notice: notice, alert: alert)
    end

    def revoke
      claim = requested_resource
      revocation_reason = params[:revocation_reason]

      if revocation_reason.blank?
        redirect_to admin_school_claim_path(claim),
                    alert: "Revocation reason is required."
        return
      end

      if claim.can_revoke?
        claim.revoke!(current_admin_user, reason: revocation_reason)
        redirect_to admin_school_claim_path(claim),
                    notice: "School claim revoked successfully. School is now available for new claims."
      else
        redirect_to admin_school_claim_path(claim),
                    alert: "Cannot revoke this claim. It may not be approved or already revoked."
      end
    end

    def bulk_revoke
      claim_ids = params[:claim_ids] || []
      revocation_reason = params[:revocation_reason]

      if claim_ids.empty?
        redirect_back(fallback_location: admin_school_claims_path, alert: "No claims selected for revocation.")
        return
      end

      if revocation_reason.blank?
        redirect_back(fallback_location: admin_school_claims_path, alert: "Revocation reason is required.")
        return
      end

      claims = SchoolClaim.where(id: claim_ids).approved
      revoked_count = 0
      errors = []

      claims.each do |claim|
        if claim.can_revoke?
          begin
            claim.revoke!(current_admin_user, reason: revocation_reason)
            revoked_count += 1
          rescue => e
            errors << "Failed to revoke claim for #{claim.school.name}: #{e.message}"
          end
        else
          errors << "Cannot revoke claim for #{claim.school.name}: not approved or already revoked"
        end
      end

      if revoked_count > 0
        notice = "Successfully revoked #{revoked_count} claim#{'s' if revoked_count != 1}."
      else
        notice = nil
      end

      if errors.any?
        alert = "Some claims could not be processed: #{errors.join(', ')}"
      else
        alert = nil
      end

      redirect_back(fallback_location: admin_school_claims_path, notice: notice, alert: alert)
    end

    private

    def find_school_claim
      @school_claim = SchoolClaim.includes(:school, :user).find(params[:id])
    end

    def find_resource(param)
      SchoolClaim.find(param)
    end

    def school_claim_params
      params.require(:school_claim).permit(:school_id, :user_id, :status, :admin_notes, :evidence_url, :revocation_reason)
    end

    # Inherit current_admin_user from ApplicationController
  end
end
