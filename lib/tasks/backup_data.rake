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
    backup_dir = Rails.root.join('tmp', 'backups')
    FileUtils.mkdir_p(backup_dir)
    
    # Generate timestamp for filename
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    
    case adapter
    when 'postgresql'
      backup_postgresql(config, backup_dir, timestamp)
    when 'postgis'
        backup_postgresql(config, backup_dir, timestamp)  
    when 'mysql2'
      backup_mysql(config, backup_dir, timestamp)
    when 'sqlite3'
      backup_sqlite(config, backup_dir, timestamp)
    else
      puts "Unsupported database adapter: #{adapter}"
      exit 1
    end
  end
  
  desc "Backup database with custom filename"
  task :backup_with_name, [:filename] => :environment do |t, args|
    filename = args[:filename] || "backup_#{Time.current.strftime('%Y%m%d_%H%M%S')}"
    
    puts "Starting database backup with filename: #{filename}"
    
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    adapter = config[:adapter]
    
    backup_dir = Rails.root.join('tmp', 'backups')
    FileUtils.mkdir_p(backup_dir)
    
    case adapter
    when 'postgresql'
      backup_postgresql(config, backup_dir, filename)
    when 'mysql2'
      backup_mysql(config, backup_dir, filename)
    when 'sqlite3'
      backup_sqlite(config, backup_dir, filename)
    else
      puts "Unsupported database adapter: #{adapter}"
      exit 1
    end
  end
  
  desc "List all database backups"
  task list_backups: :environment do
    backup_dir = Rails.root.join('tmp', 'backups')
    
    if Dir.exist?(backup_dir)
      backups = Dir.glob(File.join(backup_dir, '*')).sort.reverse
      
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
  
  desc "Clean old backups (keeps last 5)"
  task clean_backups: :environment do
    backup_dir = Rails.root.join('tmp', 'backups')
    
    if Dir.exist?(backup_dir)
      backups = Dir.glob(File.join(backup_dir, '*')).sort
      
      if backups.length > 5
        old_backups = backups[0...-5]
        puts "Removing #{old_backups.length} old backup(s):"
        
        old_backups.each do |backup|
          puts "  - #{File.basename(backup)}"
          File.delete(backup)
        end
        
        puts "Cleanup completed!"
      else
        puts "Less than 5 backups found. No cleanup needed."
      end
    else
      puts "Backup directory doesn't exist: #{backup_dir}"
    end
  end

  private

  def backup_postgresql(config, backup_dir, timestamp)
    database = config[:database]
    username = config[:username]
    password = config[:password]
    host = config[:host] || 'localhost'
    port = config[:port] || 5432
    
    backup_file = backup_dir.join("#{database}_#{timestamp}.sql")
    
    # Build pg_dump command
    cmd = ["pg_dump"]
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
    env['PGPASSWORD'] = password if password
    
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
    host = config[:host] || 'localhost'
    port = config[:port] || 3306
    
    backup_file = backup_dir.join("#{database}_#{timestamp}.sql")
    
    # Build mysqldump command
    cmd = ["mysqldump"]
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

  def backup_sqlite(config, backup_dir, timestamp)
    database_path = config[:database]
    
    # Handle relative paths
    if database_path.start_with?(':')
      # Handle in-memory databases
      puts "❌ Cannot backup in-memory SQLite database"
      exit 1
    elsif !database_path.start_with?('/')
      # Relative path - make it relative to Rails root
      database_path = Rails.root.join(database_path).to_s
    end
    
    unless File.exist?(database_path)
      puts "❌ Database file not found: #{database_path}"
      exit 1
    end
    
    database_name = File.basename(database_path, '.*')
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