module Admin
  class AuditLogsController < Admin::ApplicationController

    def index
      search_term = params[:search]
      
      @audit_logs = AuditLog.includes(:auditable).order(created_at: :desc)
      
      # Apply search filter
      if search_term.present?
        @audit_logs = @audit_logs.joins(
          "LEFT JOIN places ON audit_logs.auditable_type = 'Place' AND audit_logs.auditable_id = places.id"
        ).joins(
          "LEFT JOIN schools ON audit_logs.auditable_type = 'School' AND audit_logs.auditable_id = schools.id"
        ).where(
          "audit_logs.action ILIKE ? OR places.name ILIKE ? OR schools.name ILIKE ? OR audit_logs.auditable_type ILIKE ?",
          "%#{search_term}%", "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
        )
      end
      
      # Apply action filter
      if params[:action_filter].present?
        @audit_logs = @audit_logs.by_action(params[:action_filter])
      end
      
      # Apply model filter
      if params[:model_filter].present?
        @audit_logs = @audit_logs.by_model(params[:model_filter])
      end
      
      # Apply date filter
      if params[:date_filter].present?
        case params[:date_filter]
        when 'today'
          @audit_logs = @audit_logs.where(created_at: Date.current.beginning_of_day..Date.current.end_of_day)
        when 'week'
          @audit_logs = @audit_logs.where(created_at: 1.week.ago..Time.current)
        when 'month'
          @audit_logs = @audit_logs.where(created_at: 1.month.ago..Time.current)
        end
      end
      
      @audit_logs = @audit_logs.limit(100)
      
      # Statistics
      @total_logs = AuditLog.count
      @today_logs = AuditLog.where(created_at: Date.current.beginning_of_day..Date.current.end_of_day).count
      @week_logs = AuditLog.where(created_at: 1.week.ago..Time.current).count
      @significant_changes = AuditLog.where(
        "action IN (?) OR (changed_fields IS NOT NULL AND changed_fields != '{}')",
        %w[create delete submit approve reject suspend publish unpublish]
      ).count
      @model_counts = AuditLog.group(:auditable_type).count
      @action_counts = AuditLog.group(:action).count
      
      # Available actions and models for filters
      @available_actions = AuditLog.distinct.pluck(:action).compact.sort
      @available_models = AuditLog.distinct.pluck(:auditable_type).compact.sort
    end

    def show
      @audit_log = AuditLog.find(params[:id])
    end

    private

    def find_resource(param)
      AuditLog.find(param)
    end
  end
end
