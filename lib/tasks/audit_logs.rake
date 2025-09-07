namespace :audit_logs do
  desc "Test enhanced audit logging with sample data"
  task test_enhanced_logging: :environment do
    puts "🔍 Testing Enhanced Audit Logging System"
    puts "=" * 50

    # Find a school to test with
    school = School.first

    if school.nil?
      puts "❌ No schools found in database. Please create a school first."
      exit 1
    end

    puts "📍 Using school: #{school.name}"
    puts "📋 Current audit log count: #{AuditLog.count}"

    # Create a test audit log using the enhanced method
    original_name = school.name
    original_about = school.about

    # Simulate changes to the school
    puts "\n🔧 Making test changes to school..."
    school.name = "#{original_name} (Test Update)"
    school.about = "Enhanced audit logging test - #{Time.current}"

    if school.save
      puts "✅ School updated successfully"

      # Create audit log with enhanced tracking
      puts "\n📝 Creating enhanced audit log..."

      AuditLog.create_for_record(
        school,
        "update",
        nil, # user_id - could be set to a real user if available
        school.previous_changes
      )

      latest_audit = AuditLog.last

      puts "\n📊 Audit Log Created:"
      puts "   ID: #{latest_audit.id}"
      puts "   Action: #{latest_audit.action}"
      puts "   Model: #{latest_audit.auditable_type}"
      puts "   Changes: #{latest_audit.changed_fields.keys.join(', ')}"

      # Display field-by-field changes
      puts "\n🔍 Detailed Field Changes:"
      latest_audit.changed_fields.each do |field, changes|
        old_val = changes[0]
        new_val = changes[1]
        puts "   #{field.humanize}:"
        puts "     Old: #{old_val.inspect}"
        puts "     New: #{new_val.inspect}"
      end

      # Restore original values
      puts "\n♻️  Restoring original values..."
      school.update!(name: original_name, about: original_about)

      puts "\n📋 Final audit log count: #{AuditLog.count}"
      puts "✅ Enhanced audit logging test completed successfully!"

    else
      puts "❌ Failed to update school: #{school.errors.full_messages.join(', ')}"
    end
  end

  desc "Display recent audit logs with detailed changes"
  task show_recent: :environment do
    puts "📋 Recent Audit Logs with Enhanced Data"
    puts "=" * 60

    recent_logs = AuditLog.includes(:auditable).order(created_at: :desc).limit(10)

    recent_logs.each do |log|
      puts "\n🔍 Log ##{log.id} (#{log.created_at.strftime('%Y-%m-%d %H:%M:%S')})"
      puts "   Action: #{log.action_description}"
      puts "   Model: #{log.auditable_type} ##{log.auditable_id}"

      if log.auditable
        name = log.auditable.try(:name) || log.auditable.try(:label)
        puts "   Record: #{name}" if name
      end

      if log.changed_fields.present? && log.changed_fields.any?
        puts "   📝 Changes:"
        log.changed_fields.each do |field, changes|
          if changes.is_a?(Array) && changes.size == 2
            old_val = changes[0]
            new_val = changes[1]
            puts "     #{field.humanize}: #{old_val.inspect} → #{new_val.inspect}"
          else
            puts "     #{field.humanize}: #{changes.inspect}"
          end
        end
      else
        puts "   📝 No detailed changes recorded"
      end
    end
  end

  desc "Clean up old audit logs (keeps last 1000)"
  task cleanup_old: :environment do
    puts "🧹 Cleaning up old audit logs..."

    total_logs = AuditLog.count
    puts "Total audit logs: #{total_logs}"

    if total_logs > 1000
      old_logs = AuditLog.order(created_at: :asc).limit(total_logs - 1000)
      deleted_count = old_logs.delete_all

      puts "✅ Deleted #{deleted_count} old audit logs"
      puts "📋 Remaining logs: #{AuditLog.count}"
    else
      puts "📋 No cleanup needed (#{total_logs} logs)"
    end
  end
end
