namespace :data do
  desc "Migrate Facebook URLs from website_url to facebook_url field"
  task :migrate_facebook_urls, [ :dry_run ] => :environment do |_task, args|
    dry_run = args[:dry_run] == "true" || args[:dry_run] == "dry_run"

    puts "🔄 Facebook URL Migration Task"
    puts "Mode: #{dry_run ? '🔍 DRY RUN (no changes will be made)' : '✏️  LIVE MODE (changes will be applied)'}"
    puts "=" * 60

    # Find schools with Facebook URLs in website_url field
    facebook_patterns = [
      "%facebook.com%",
      "%fb.com%",
      "%m.facebook.com%"
    ]

    schools_to_migrate = []
    facebook_patterns.each do |pattern|
      found_schools = School.where("website_url ILIKE ?", pattern)
      schools_to_migrate.concat(found_schools.to_a)
    end

    # Remove duplicates
    schools_to_migrate = schools_to_migrate.uniq

    puts "📊 Found #{schools_to_migrate.count} schools with Facebook URLs in website_url field"

    if schools_to_migrate.empty?
      puts "✅ No Facebook URLs found in website_url field. Migration not needed."
      exit 0
    end

    # Show preview of changes
    puts "\n📋 Schools to be migrated:"
    puts "-" * 60

    migration_count = 0
    conflict_count = 0

    schools_to_migrate.each_with_index do |school, index|
      puts "#{index + 1}. #{school.name} (ID: #{school.id})"
      puts "   Current website_url: #{school.website_url}"
      puts "   Current facebook_url: #{school.facebook_url || 'NULL'}"

      # Check for conflicts
      if school.facebook_url.present?
        puts "   ⚠️  CONFLICT: facebook_url already populated!"
        conflict_count += 1
      else
        migration_count += 1
      end

      puts "   → Will move to facebook_url: #{school.website_url}"
      puts "   → Will set website_url to: NULL"
      puts ""
    end

    puts "=" * 60
    puts "📈 Migration Summary:"
    puts "   Schools to migrate: #{migration_count}"
    puts "   Conflicts (skipped): #{conflict_count}" if conflict_count > 0
    puts "=" * 60

    if dry_run
      puts "🔍 DRY RUN COMPLETE - No changes were made"
      puts "   To apply changes, run: rails data:migrate_facebook_urls[live]"
      exit 0
    end

    # Confirm before proceeding with live migration
    if conflict_count > 0
      puts "⚠️  WARNING: #{conflict_count} schools have conflicts and will be skipped"
    end

    print "Continue with migration? (y/N): "
    response = STDIN.gets.chomp.downcase
    unless response == "y" || response == "yes"
      puts "❌ Migration cancelled"
      exit 0
    end

    # Create backup before migration
    puts "\n📄 Creating database backup before migration..."
    system("rails data:backup")
    puts "✅ Backup created"

    # Perform the migration
    puts "\n🚀 Starting Facebook URL migration..."
    success_count = 0
    error_count = 0
    skipped_count = 0

    schools_to_migrate.each_with_index do |school, index|
      begin
        if school.facebook_url.present?
          puts "#{index + 1}/#{schools_to_migrate.count} ⏭️  Skipped: #{school.name} (facebook_url already exists)"
          skipped_count += 1
          next
        end

        # Perform the migration
        School.transaction do
          school.update!(
            facebook_url: school.website_url,
            website_url: nil
          )
        end

        puts "#{index + 1}/#{schools_to_migrate.count} ✅ Migrated: #{school.name}"
        success_count += 1

      rescue StandardError => e
        puts "#{index + 1}/#{schools_to_migrate.count} ❌ Error: #{school.name} - #{e.message}"
        error_count += 1
      end
    end

    puts "\n🎉 Facebook URL Migration Complete!"
    puts "=" * 60
    puts "📊 Final Results:"
    puts "   ✅ Successfully migrated: #{success_count}"
    puts "   ⏭️  Skipped (conflicts): #{skipped_count}" if skipped_count > 0
    puts "   ❌ Errors: #{error_count}" if error_count > 0
    puts "=" * 60

    if success_count > 0
      puts "✨ Migration successful! Facebook URLs have been moved to the facebook_url field."
      puts "🔍 You can verify the changes in the admin interface at /admin/schools"
    end

    if error_count > 0
      puts "⚠️  Some migrations failed. Check the errors above and consider re-running for failed schools."
    end
  end

  desc "Rollback Facebook URL migration (restore from facebook_url to website_url)"
  task rollback_facebook_migration: :environment do
    puts "🔄 Facebook URL Migration Rollback"
    puts "⚠️  WARNING: This will move Facebook URLs back to website_url field"
    puts "=" * 60

    # Find schools with facebook_url but no website_url
    schools_to_rollback = School.where.not(facebook_url: nil).where(website_url: nil)

    puts "📊 Found #{schools_to_rollback.count} schools that can be rolled back"

    if schools_to_rollback.empty?
      puts "✅ No schools found for rollback. Nothing to do."
      exit 0
    end

    # Show preview
    puts "\n📋 Schools to be rolled back:"
    puts "-" * 60
    schools_to_rollback.each_with_index do |school, index|
      puts "#{index + 1}. #{school.name} (ID: #{school.id})"
      puts "   facebook_url: #{school.facebook_url}"
      puts "   → Will restore to website_url"
      puts ""
    end

    print "Continue with rollback? (y/N): "
    response = STDIN.gets.chomp.downcase
    unless response == "y" || response == "yes"
      puts "❌ Rollback cancelled"
      exit 0
    end

    puts "\n🚀 Starting rollback..."
    success_count = 0

    schools_to_rollback.each_with_index do |school, index|
      begin
        School.transaction do
          school.update!(
            website_url: school.facebook_url,
            facebook_url: nil
          )
        end

        puts "#{index + 1}/#{schools_to_rollback.count} ✅ Rolled back: #{school.name}"
        success_count += 1

      rescue StandardError => e
        puts "#{index + 1}/#{schools_to_rollback.count} ❌ Error: #{school.name} - #{e.message}"
      end
    end

    puts "\n🎉 Rollback Complete!"
    puts "✅ Successfully rolled back: #{success_count} schools"
  end
end
