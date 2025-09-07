# lib/tasks/data.rake

namespace :data do
  desc "Backup the database"
  task backup: :environment do
    puts "Starting database backup..."

    # Get database configuration
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    adapter = config[:adapter]
    database = config[:database]

    # Create backups directory if it doesn't exist
    backup_dir = Rails.root.join("tmp", "backups")
    FileUtils.mkdir_p(backup_dir)

    # Generate timestamp for filename
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")

    case adapter
    when "postgresql"
      backup_postgresql(config, backup_dir, timestamp)
    when "postgis"
        backup_postgresql(config, backup_dir, timestamp)
    when "mysql2"
      backup_mysql(config, backup_dir, timestamp)
    when "sqlite3"
      backup_sqlite(config, backup_dir, timestamp)
    else
      puts "Unsupported database adapter: #{adapter}"
      exit 1
    end
  end

  desc "Backup database with custom filename"
  task :backup_with_name, [ :filename ] => :environment do |t, args|
    filename = args[:filename] || "backup_#{Time.current.strftime('%Y%m%d_%H%M%S')}"

    puts "Starting database backup with filename: #{filename}"

    config = ActiveRecord::Base.connection_db_config.configuration_hash
    adapter = config[:adapter]

    backup_dir = Rails.root.join("tmp", "backups")
    FileUtils.mkdir_p(backup_dir)

    case adapter
    when "postgresql"
      backup_postgresql(config, backup_dir, filename)
    when "mysql2"
      backup_mysql(config, backup_dir, filename)
    when "sqlite3"
      backup_sqlite(config, backup_dir, filename)
    else
      puts "Unsupported database adapter: #{adapter}"
      exit 1
    end
  end

  desc "List all database backups"
  task list_backups: :environment do
    backup_dir = Rails.root.join("tmp", "backups")

    if Dir.exist?(backup_dir)
      backups = Dir.glob(File.join(backup_dir, "*")).sort.reverse

      if backups.any?
        puts "\nAvailable backups:"
        puts "-" * 50
        backups.each do |backup|
          file_info = File.stat(backup)
          size = (file_info.size / 1024.0 / 1024.0).round(2)
          puts "#{File.basename(backup)} (#{size} MB) - #{file_info.mtime.strftime('%Y-%m-%d %H:%M:%S')}"
        end
      else
        puts "No backups found in #{backup_dir}"
      end
    else
      puts "Backup directory doesn't exist: #{backup_dir}"
    end
  end

  desc "Restore database from backup (latest by default)"
  task restore: :environment do
    backup_dir = Rails.root.join("tmp", "backups")

    unless Dir.exist?(backup_dir)
      puts "❌ Backup directory doesn't exist: #{backup_dir}"
      next
    end

    backups = Dir.glob(File.join(backup_dir, "*")).sort.reverse

    if backups.empty?
      puts "❌ No backup files found in #{backup_dir}"
      puts "💡 Create a backup first with: rails data:backup"
      next
    end

    latest_backup = backups.first

    puts "🔄 Database Restore"
    puts "=" * 50
    puts "Latest backup: #{File.basename(latest_backup)}"
    puts "Created: #{File.stat(latest_backup).mtime.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "Size: #{(File.size(latest_backup) / 1024.0 / 1024.0).round(2)} MB"
    puts ""

    # 🛡️ SAFETY CHECK: Follow CLAUDE.md protection rules
    puts "⚠️  WARNING: This will completely replace your current database"
    puts "Current database will be DELETED and replaced with backup data"
    puts ""
    puts "📊 Current database counts:"
    begin
      puts "   Places: #{Place.count}"
      puts "   Points: #{Point.count}"
      puts "   Schools: #{School.count}"
    rescue => e
      puts "   Unable to count records: #{e.message}"
    end
    puts ""

    print "Continue? Type 'RESTORE CONFIRMED' to proceed: "
    confirmation = STDIN.gets.chomp
    unless confirmation == "RESTORE CONFIRMED"
      puts "❌ Operation cancelled - database preserved"
      next
    end

    # Perform restore
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    adapter = config[:adapter]

    case adapter
    when "postgresql", "postgis"
      restore_postgresql(config, latest_backup)
    when "mysql2"
      restore_mysql(config, latest_backup)
    when "sqlite3"
      restore_sqlite(config, latest_backup)
    else
      puts "❌ Unsupported database adapter: #{adapter}"
      next
    end
  end

  desc "Restore database from specific backup file"
  task :restore_from, [ :filename ] => :environment do |t, args|
    unless args[:filename]
      puts "❌ Please specify a backup filename"
      puts "Usage: rails data:restore_from[filename.sql]"
      puts "Available backups:"
      Rake::Task["data:list_backups"].invoke
      next
    end

    backup_dir = Rails.root.join("tmp", "backups")
    backup_file = backup_dir.join(args[:filename])

    unless File.exist?(backup_file)
      puts "❌ Backup file not found: #{backup_file}"
      puts "Available backups:"
      Rake::Task["data:list_backups"].invoke
      next
    end

    puts "🔄 Database Restore from Specific File"
    puts "=" * 50
    puts "Backup file: #{args[:filename]}"
    puts "Created: #{File.stat(backup_file).mtime.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "Size: #{(File.size(backup_file) / 1024.0 / 1024.0).round(2)} MB"
    puts ""

    # 🛡️ SAFETY CHECK: Follow CLAUDE.md protection rules
    puts "⚠️  WARNING: This will completely replace your current database"
    puts "Current database will be DELETED and replaced with backup data"
    puts ""
    puts "📊 Current database counts:"
    begin
      puts "   Places: #{Place.count}"
      puts "   Points: #{Point.count}"
      puts "   Schools: #{School.count}"
    rescue => e
      puts "   Unable to count records: #{e.message}"
    end
    puts ""

    print "Continue? Type 'RESTORE CONFIRMED' to proceed: "
    confirmation = STDIN.gets.chomp
    unless confirmation == "RESTORE CONFIRMED"
      puts "❌ Operation cancelled - database preserved"
      next
    end

    # Perform restore
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    adapter = config[:adapter]

    case adapter
    when "postgresql", "postgis"
      restore_postgresql(config, backup_file)
    when "mysql2"
      restore_mysql(config, backup_file)
    when "sqlite3"
      restore_sqlite(config, backup_file)
    else
      puts "❌ Unsupported database adapter: #{adapter}"
      next
    end
  end

  desc "Clean old backups (keeps last 5)"
  task clean_backups: :environment do
    backup_dir = Rails.root.join("tmp", "backups")

    unless Dir.exist?(backup_dir)
      puts "Backup directory doesn't exist: #{backup_dir}"
      next
    end

    backups = Dir.glob(File.join(backup_dir, "*")).sort

    if backups.length <= 5
      puts "Less than 5 backups found (#{backups.length}). No cleanup needed."
      next
    end

    old_backups = backups[0...-5]

    # 🛡️ SAFETY CHECK: Follow CLAUDE.md protection rules
    puts "⚠️  WARNING: About to delete backup files"
    puts "Files to delete: #{old_backups.length}"
    puts "Sample files:"
    old_backups.first(3).each do |backup|
      file_info = File.stat(backup)
      puts "  - #{File.basename(backup)} (#{(file_info.size / 1024.0 / 1024.0).round(2)} MB, #{file_info.mtime.strftime('%Y-%m-%d %H:%M:%S')})"
    end
    puts ""
    puts "Keeping #{backups.last(5).length} most recent backups"
    puts ""

    print "Continue? Type 'DELETE CONFIRMED' to proceed: "
    confirmation = STDIN.gets.chomp
    unless confirmation == "DELETE CONFIRMED"
      puts "❌ Operation cancelled - backup files preserved"
      next
    end

    puts "Removing #{old_backups.length} old backup(s):"
    old_backups.each do |backup|
      puts "  - #{File.basename(backup)}"
      File.delete(backup)
    end

    puts "✅ Cleanup completed!"
  end

  private

  def backup_postgresql(config, backup_dir, timestamp)
    database = config[:database]
    username = config[:username]
    password = config[:password]
    host = config[:host] || "localhost"
    port = config[:port] || 5432

    backup_file = backup_dir.join("#{database}_#{timestamp}.sql")

    # Build pg_dump command
    cmd = [ "pg_dump" ]
    cmd << "--host=#{host}"
    cmd << "--port=#{port}"
    cmd << "--username=#{username}" if username
    cmd << "--no-password"
    cmd << "--verbose"
    cmd << "--clean"
    cmd << "--no-owner"
    cmd << "--no-privileges"
    cmd << "--format=custom"
    cmd << "--file=#{backup_file}"
    cmd << database

    # Set password environment variable if provided
    env = {}
    env["PGPASSWORD"] = password if password

    puts "Creating PostgreSQL backup: #{backup_file}"

    if system(env, *cmd)
      puts "✅ PostgreSQL backup completed successfully!"
      puts "📁 Backup saved to: #{backup_file}"
      puts "📊 File size: #{(File.size(backup_file) / 1024.0 / 1024.0).round(2)} MB"
    else
      puts "❌ PostgreSQL backup failed!"
      exit 1
    end
  end

  def backup_mysql(config, backup_dir, timestamp)
    database = config[:database]
    username = config[:username]
    password = config[:password]
    host = config[:host] || "localhost"
    port = config[:port] || 3306

    backup_file = backup_dir.join("#{database}_#{timestamp}.sql")

    # Build mysqldump command
    cmd = [ "mysqldump" ]
    cmd << "--host=#{host}"
    cmd << "--port=#{port}"
    cmd << "--user=#{username}" if username
    cmd << "--password=#{password}" if password
    cmd << "--single-transaction"
    cmd << "--routines"
    cmd << "--triggers"
    cmd << "--result-file=#{backup_file}"
    cmd << database

    puts "Creating MySQL backup: #{backup_file}"

    if system(*cmd)
      puts "✅ MySQL backup completed successfully!"
      puts "📁 Backup saved to: #{backup_file}"
      puts "📊 File size: #{(File.size(backup_file) / 1024.0 / 1024.0).round(2)} MB"
    else
      puts "❌ MySQL backup failed!"
      exit 1
    end
  end

  def restore_postgresql(config, backup_file)
    database = config[:database]
    username = config[:username]
    password = config[:password]
    host = config[:host] || "localhost"
    port = config[:port] || 5432

    puts "🔄 Restoring PostgreSQL database from: #{File.basename(backup_file)}"

    # Build pg_restore command
    cmd = [ "pg_restore" ]
    cmd << "--host=#{host}"
    cmd << "--port=#{port}"
    cmd << "--username=#{username}" if username
    cmd << "--no-password"
    cmd << "--verbose"
    cmd << "--clean"
    cmd << "--if-exists"
    cmd << "--no-owner"
    cmd << "--no-privileges"
    cmd << "--dbname=#{database}"
    cmd << backup_file.to_s

    # Set password environment variable if provided
    env = {}
    env["PGPASSWORD"] = password if password

    puts "Executing restore..."
    if system(env, *cmd)
      puts "✅ PostgreSQL restore completed successfully!"

      # Show final counts
      puts "\n📊 Restored database counts:"
      begin
        puts "   Places: #{Place.count}"
        puts "   Points: #{Point.count}"
        puts "   Schools: #{School.count}"
      rescue => e
        puts "   Unable to count records: #{e.message}"
      end
    else
      puts "❌ PostgreSQL restore failed!"
      puts "💡 Check that the database exists and you have proper permissions"
      exit 1
    end
  end

  def restore_mysql(config, backup_file)
    database = config[:database]
    username = config[:username]
    password = config[:password]
    host = config[:host] || "localhost"
    port = config[:port] || 3306

    puts "🔄 Restoring MySQL database from: #{File.basename(backup_file)}"

    # Build mysql command
    cmd = [ "mysql" ]
    cmd << "--host=#{host}"
    cmd << "--port=#{port}"
    cmd << "--user=#{username}" if username
    cmd << "--password=#{password}" if password
    cmd << database

    puts "Executing restore..."
    if system("#{cmd.join(' ')} < #{backup_file}")
      puts "✅ MySQL restore completed successfully!"

      # Show final counts
      puts "\n📊 Restored database counts:"
      begin
        puts "   Places: #{Place.count}"
        puts "   Points: #{Point.count}"
        puts "   Schools: #{School.count}"
      rescue => e
        puts "   Unable to count records: #{e.message}"
      end
    else
      puts "❌ MySQL restore failed!"
      exit 1
    end
  end

  def restore_sqlite(config, backup_file)
    database_path = config[:database]

    # Handle relative paths
    if database_path.start_with?(":")
      puts "❌ Cannot restore to in-memory SQLite database"
      exit 1
    elsif !database_path.start_with?("/")
      database_path = Rails.root.join(database_path).to_s
    end

    puts "🔄 Restoring SQLite database from: #{File.basename(backup_file)}"

    begin
      # Create backup of current database
      current_backup = "#{database_path}.pre_restore_#{Time.current.strftime('%Y%m%d_%H%M%S')}"
      FileUtils.cp(database_path, current_backup) if File.exist?(database_path)
      puts "📁 Current database backed up to: #{File.basename(current_backup)}"

      # Restore from backup
      FileUtils.cp(backup_file, database_path)

      puts "✅ SQLite restore completed successfully!"

      # Show final counts
      puts "\n📊 Restored database counts:"
      begin
        # Reconnect to updated database
        ActiveRecord::Base.connection.reconnect!
        puts "   Places: #{Place.count}"
        puts "   Points: #{Point.count}"
        puts "   Schools: #{School.count}"
      rescue => e
        puts "   Unable to count records: #{e.message}"
      end
    rescue => e
      puts "❌ SQLite restore failed: #{e.message}"
      exit 1
    end
  end

  def backup_sqlite(config, backup_dir, timestamp)
    database_path = config[:database]

    # Handle relative paths
    if database_path.start_with?(":")
      # Handle in-memory databases
      puts "❌ Cannot backup in-memory SQLite database"
      exit 1
    elsif !database_path.start_with?("/")
      # Relative path - make it relative to Rails root
      database_path = Rails.root.join(database_path).to_s
    end

    unless File.exist?(database_path)
      puts "❌ Database file not found: #{database_path}"
      exit 1
    end

    database_name = File.basename(database_path, ".*")
    backup_file = backup_dir.join("#{database_name}_#{timestamp}.db")

    puts "Creating SQLite backup: #{backup_file}"

    begin
      FileUtils.cp(database_path, backup_file)

      puts "✅ SQLite backup completed successfully!"
      puts "📁 Backup saved to: #{backup_file}"
      puts "📊 File size: #{(File.size(backup_file) / 1024.0 / 1024.0).round(2)} MB"
    rescue => e
      puts "❌ SQLite backup failed: #{e.message}"
      exit 1
    end
  end
end
