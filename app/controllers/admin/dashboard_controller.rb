module Admin
  class DashboardController < Admin::ApplicationController
    def index
      @pending_claims = SchoolClaim.pending.includes(:school, :user).order(created_at: :desc)
      @recent_pending_inquiries = SchoolInquiry.where(status: ['new', 'read']).includes(:school).limit(5).order(created_at: :desc)
      @recent_rejected = SchoolClaim.rejected.includes(:school, :user).limit(10).order(updated_at: :desc)
      
      @stats = {
        total_claims: SchoolClaim.count,
        pending_claims: SchoolClaim.pending.count,
        approved_claims: SchoolClaim.approved.count,
        rejected_claims: SchoolClaim.rejected.count,
        stale_claims: SchoolClaim.pending.where('created_at < ?', 30.days.ago).count,
        claims_this_week: SchoolClaim.where(created_at: 1.week.ago..Time.current).count,
        claims_this_month: SchoolClaim.where(created_at: 1.month.ago..Time.current).count
      }
      
      @total_schools = School.count
      @claimed_schools = School.joins(:school_claims).where(school_claims: { status: 'approved' }).distinct.count
      @unclaimed_schools = @total_schools - @claimed_schools
    end
  end
end