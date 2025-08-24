# AuditLog model provides comprehensive change tracking for any model with polymorphic associations
# Tracks who made changes, what changed, and when for compliance and rollback support
class AuditLog < ApplicationRecord
  belongs_to :auditable, polymorphic: true
  # Note: user_id will reference User model when it exists
  
  validates :action, presence: true, inclusion: { 
    in: %w[create update delete submit approve reject suspend publish unpublish]
  }
  validates :auditable_type, :auditable_id, presence: true
  
  scope :by_action, ->(action) { where(action: action) }
  scope :by_model, ->(model_type) { where(auditable_type: model_type) }
  scope :recent, ->(limit = 50) { order(created_at: :desc).limit(limit) }
  scope :for_record, ->(record) { where(auditable: record) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  
  # Get human-readable action description
  def action_description
    case action
    when 'create'
      'Created'
    when 'update'
      'Updated'
    when 'delete'
      'Deleted'
    when 'submit'
      'Submitted for review'
    when 'approve'
      'Approved'
    when 'reject'
      'Rejected'
    when 'suspend'
      'Suspended'
    when 'publish'
      'Published'
    when 'unpublish'
      'Unpublished'
    else
      action.humanize
    end
  end
  
  # Get changed field names as readable list
  def changed_fields_display
    return 'No changes recorded' if changed_fields.blank?
    
    fields = changed_fields.keys.map(&:humanize)
    
    case fields.size
    when 1
      fields.first
    when 2
      fields.join(' and ')
    else
      "#{fields[0...-1].join(', ')}, and #{fields.last}"
    end
  end
  
  # Get summary of changes for display
  def change_summary
    return "#{action_description} #{auditable_type.underscore.humanize.downcase}" if changed_fields.blank?
    
    "#{action_description} #{changed_fields_display.downcase}"
  end
  
  # Check if this was a significant change (not just timestamps)
  def significant_change?
    return true if %w[create delete submit approve reject suspend publish unpublish].include?(action)
    return false if changed_fields.blank?
    
    # Ignore timestamp-only changes
    significant_fields = changed_fields.keys - %w[updated_at created_at]
    significant_fields.any?
  end
  
  # Get the previous value for a field
  def previous_value(field)
    changed_fields.dig(field.to_s, 0)
  end
  
  # Get the new value for a field  
  def new_value(field)
    changed_fields.dig(field.to_s, 1)
  end
  
  # Time since this change was made
  def time_ago
    time_diff = Time.current - created_at
    
    case time_diff
    when 0..59
      "#{time_diff.to_i} seconds ago"
    when 60..3599
      "#{(time_diff / 60).to_i} minutes ago"
    when 3600..86399
      "#{(time_diff / 3600).to_i} hours ago"
    else
      "#{(time_diff / 86400).to_i} days ago"
    end
  end
end