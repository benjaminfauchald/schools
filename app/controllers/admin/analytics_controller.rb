module Admin
  class AnalyticsController < Admin::ApplicationController
    def index
      @mixpanel_token = ENV["MIXPANEL_TOKEN"]
      @mixpanel_api_key = ENV["MIXPANEL_API_KEY"]

      # Basic stats from database
      @stats = {
        users: {
          total: User.count,
          registered_today: User.where(created_at: Date.current.all_day).count,
          registered_this_week: User.where(created_at: 1.week.ago..Time.current).count,
          registered_this_month: User.where(created_at: 1.month.ago..Time.current).count,
          facebook_users: User.where.not(provider: nil).count,
          email_users: User.where(provider: nil).count
        },
        schools: {
          total: School.count,
          claimed: School.joins(:school_claims).where(school_claims: { status: "approved" }).distinct.count,
          with_inquiries: School.joins(:school_inquiries).distinct.count,
          most_viewed: popular_schools_this_week
        },
        inquiries: {
          total: SchoolInquiry.count,
          today: SchoolInquiry.where(created_at: Date.current.all_day).count,
          this_week: SchoolInquiry.where(created_at: 1.week.ago..Time.current).count,
          this_month: SchoolInquiry.where(created_at: 1.month.ago..Time.current).count,
          pending_response: SchoolInquiry.where(status: [ "new", "read" ]).count
        },
        claims: {
          total: SchoolClaim.count,
          pending: SchoolClaim.pending.count,
          approved: SchoolClaim.approved.count,
          rejected: SchoolClaim.rejected.count
        }
      }

      # Top performing schools by inquiries
      @top_schools_by_inquiries = School
        .joins(:school_inquiries)
        .where(school_inquiries: { created_at: 30.days.ago..Time.current })
        .group("schools.id", "schools.name")
        .order("COUNT(school_inquiries.id) DESC")
        .limit(10)
        .pluck("schools.name", "COUNT(school_inquiries.id)")

      # Recent activity
      @recent_registrations = User.order(created_at: :desc).limit(10)
      @recent_inquiries = SchoolInquiry.includes(:school, :user).order(created_at: :desc).limit(10)
      @recent_claims = SchoolClaim.includes(:school, :user).order(created_at: :desc).limit(10)

      # User locations (for geographic insights)
      @user_areas = get_user_areas_distribution
    end

    private

    def popular_schools_this_week
      # This would ideally come from Mixpanel data
      # For now, we'll use inquiry data as a proxy
      School
        .joins(:school_inquiries)
        .where(school_inquiries: { created_at: 1.week.ago..Time.current })
        .group("schools.id")
        .order("COUNT(school_inquiries.id) DESC")
        .limit(5)
        .pluck(:name)
    end

    def get_user_areas_distribution
      # Parse user location cookies from recent sessions
      # This is a simplified version - in production you'd want to store this data properly
      areas = {}

      # Count inquiries by school area as a proxy for user interest areas
      School
        .joins(:school_inquiries)
        .where.not(area: [ nil, "" ])
        .where(school_inquiries: { created_at: 30.days.ago..Time.current })
        .group(:area)
        .count
        .sort_by { |_, count| -count }
        .first(10)
    end
  end
end
