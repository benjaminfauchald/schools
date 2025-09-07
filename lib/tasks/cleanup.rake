namespace :cleanup do
  desc "Clean up old temp claims"
  task temp_claims: :environment do
    puts "Cleaning up old temp claims..."

    # Remove temp claims older than 30 days
    old_temp_claims = TempClaim.where("created_at < ?", 30.days.ago)
    count = old_temp_claims.count

    if count > 0
      puts "Found #{count} temp claims older than 30 days"
      old_temp_claims.destroy_all
      puts "Deleted #{count} old temp claims"
    else
      puts "No old temp claims found"
    end

    # Remove temp claims that have been registered for more than 7 days
    registered_temp_claims = TempClaim.where(status: "registered").where("updated_at < ?", 7.days.ago)
    registered_count = registered_temp_claims.count

    if registered_count > 0
      puts "Found #{registered_count} registered temp claims older than 7 days"
      registered_temp_claims.destroy_all
      puts "Deleted #{registered_count} registered temp claims"
    else
      puts "No old registered temp claims found"
    end

    puts "Temp claims cleanup completed"
  end

  desc "Clean up orphaned school claims"
  task school_claims: :environment do
    puts "Cleaning up orphaned school claims..."

    # Find school claims with users that no longer exist
    orphaned_claims = SchoolClaim.left_joins(:user).where(users: { id: nil })
    count = orphaned_claims.count

    if count > 0
      puts "Found #{count} orphaned school claims"
      orphaned_claims.destroy_all
      puts "Deleted #{count} orphaned school claims"
    else
      puts "No orphaned school claims found"
    end

    puts "School claims cleanup completed"
  end

  desc "Clean up expired magic link tokens"
  task magic_link_tokens: :environment do
    puts "Cleaning up expired magic link tokens..."

    expired_count = MagicLinkToken.expired.count
    used_old_count = MagicLinkToken.where("used_at < ?", 7.days.ago).count

    if expired_count > 0
      MagicLinkToken.expired.delete_all
      puts "Deleted #{expired_count} expired magic link tokens"
    else
      puts "No expired magic link tokens found"
    end

    if used_old_count > 0
      MagicLinkToken.where("used_at < ?", 7.days.ago).delete_all
      puts "Deleted #{used_old_count} old used magic link tokens"
    else
      puts "No old used magic link tokens found"
    end

    puts "Magic link tokens cleanup completed"
  end

  desc "Run all cleanup tasks"
  task all: :environment do
    Rake::Task["cleanup:temp_claims"].invoke
    Rake::Task["cleanup:school_claims"].invoke
    Rake::Task["cleanup:magic_link_tokens"].invoke
    puts "All cleanup tasks completed"
  end
end
