module Admin
  class SchoolClaimsController < Admin::ApplicationController
    def approve
      claim = requested_resource
      
      if claim.can_approve?
        claim.approve!(current_admin_user, notes: params[:admin_notes])
        redirect_to admin_school_claim_path(claim), 
                    notice: 'School claim approved successfully. User can now manage the school.'
      else
        redirect_to admin_school_claim_path(claim), 
                    alert: 'Cannot approve this claim. It may already be processed.'
      end
    end
    
    def reject
      claim = requested_resource
      
      if claim.can_reject?
        claim.reject!(current_admin_user, notes: params[:admin_notes] || 'Claim rejected by admin')
        redirect_to admin_school_claim_path(claim), 
                    notice: 'School claim rejected.'
      else
        redirect_to admin_school_claim_path(claim), 
                    alert: 'Cannot reject this claim. It may already be processed.'
      end
    end
    
    def bulk_approve
      claim_ids = params[:claim_ids] || []
      admin_notes = params[:admin_notes] || 'Bulk approved by admin'
      
      if claim_ids.empty?
        redirect_back(fallback_location: admin_school_claims_path, alert: 'No claims selected for approval.')
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
      admin_notes = params[:admin_notes] || 'Bulk rejected by admin'
      
      if claim_ids.empty?
        redirect_back(fallback_location: admin_school_claims_path, alert: 'No claims selected for rejection.')
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
                    alert: 'Revocation reason is required.'
        return
      end
      
      if claim.can_revoke?
        claim.revoke!(current_admin_user, reason: revocation_reason)
        redirect_to admin_school_claim_path(claim), 
                    notice: 'School claim revoked successfully. School is now available for new claims.'
      else
        redirect_to admin_school_claim_path(claim), 
                    alert: 'Cannot revoke this claim. It may not be approved or already revoked.'
      end
    end
    
    def bulk_revoke
      claim_ids = params[:claim_ids] || []
      revocation_reason = params[:revocation_reason]
      
      if claim_ids.empty?
        redirect_back(fallback_location: admin_school_claims_path, alert: 'No claims selected for revocation.')
        return
      end
      
      if revocation_reason.blank?
        redirect_back(fallback_location: admin_school_claims_path, alert: 'Revocation reason is required.')
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
    
    # Inherit current_admin_user from ApplicationController
  end
end
