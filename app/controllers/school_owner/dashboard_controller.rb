class SchoolOwner::DashboardController < SchoolOwner::ApplicationController
  def index
    @owned_schools = current_user.owned_schools.includes(:place)
    @pending_claims = current_user.pending_claims.includes(:school)
    @inquiries = SchoolInquiry.joins(:school)
                             .where(schools: { id: current_user.owned_schools.select(:id) })
                             .includes(:school, :user)
                             .recent
    @recent_activity = recent_activity_for_user
  end
  
  private
  
  def recent_activity_for_user
    # Get recent activities for user's schools (if audit_logs exists)
    return [] unless defined?(AuditLog)
    
    AuditLog.where(auditable: current_user.owned_schools)
            .or(AuditLog.where(user: current_user))
            .includes(:auditable)
            .order(created_at: :desc)
            .limit(10)
  end
end