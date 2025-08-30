namespace :temp_claims do
  desc 'Clean up expired temporary claims'
  task cleanup: :environment do
    puts "Cleaning up expired temporary claims..."
    
    expired_count = TempClaim.expired.where.not(status: 'expired').count
    TempClaim.cleanup_expired!
    
    puts "Marked #{expired_count} expired claims as expired."
    
    # Optionally delete very old expired claims (older than 30 days)
    old_claims = TempClaim.where(status: 'expired').where('created_at < ?', 30.days.ago)
    old_count = old_claims.count
    old_claims.destroy_all
    
    puts "Deleted #{old_count} old expired claims (older than 30 days)."
    puts "Cleanup complete."
  end
  
  desc 'Show statistics for temporary claims'
  task stats: :environment do
    puts "Temporary Claims Statistics:"
    puts "=" * 40
    puts "Total claims: #{TempClaim.count}"
    puts "Pending registration: #{TempClaim.pending_registration.count}"
    puts "Registered: #{TempClaim.registered.count}"
    puts "Expired: #{TempClaim.expired.count}"
    puts "Active (not expired): #{TempClaim.active.count}"
    puts ""
    puts "Claims by school (top 10):"
    TempClaim.joins(:school)
             .group('schools.name')
             .count
             .sort_by { |name, count| -count }
             .first(10)
             .each { |name, count| puts "  #{name}: #{count}" }
  end
end