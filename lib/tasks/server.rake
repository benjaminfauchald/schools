namespace :server do
  desc "Kill any running Rails server on port 3000 and start a new one"
  task :restart => :environment do
    port = 3000
    
    puts "🔍 Checking for Rails server on port #{port}..."
    
    # Find process using port 3000
    pid_output = `lsof -ti:#{port}`.strip
    
    if pid_output.present?
      pids = pid_output.split("\n")
      puts "📡 Found #{pids.length} process(es) on port #{port}: #{pids.join(', ')}"
      
      pids.each do |pid|
        begin
          # Get process info
          process_info = `ps -p #{pid} -o comm= 2>/dev/null`.strip
          puts "🔫 Killing PID #{pid} (#{process_info.present? ? process_info : 'unknown'})"
          
          # Kill the process
          system("kill -TERM #{pid}")
          sleep(2) # Give it time to terminate gracefully
          
          # Check if it's still running and force kill if needed
          if `ps -p #{pid} 2>/dev/null`.present?
            puts "💥 Force killing PID #{pid}"
            system("kill -KILL #{pid}")
            sleep(1)
          end
          
          puts "✅ Successfully killed PID #{pid}"
        rescue => e
          puts "⚠️  Error killing PID #{pid}: #{e.message}"
        end
      end
      
      # Wait a moment for the port to be released
      sleep(2)
      
      # Double-check that the port is free
      remaining_processes = `lsof -ti:#{port}`.strip
      if remaining_processes.present?
        puts "❌ Warning: Port #{port} still in use by: #{remaining_processes}"
      else
        puts "✅ Port #{port} is now free"
      end
    else
      puts "✅ No processes found on port #{port}"
    end
    
    puts ""
    puts "🚀 Starting new Rails server..."
    puts "📍 Server will be available at http://localhost:#{port}"
    puts "🛑 Press Ctrl+C to stop the server"
    puts ""
    
    # Start the Rails server
    # Use bin/dev if available (includes CSS watching), otherwise use bin/rails server
    if File.exist?('bin/dev')
      puts "📦 Using bin/dev (includes Tailwind CSS watching)"
      exec('bin/dev')
    else
      puts "🎯 Using bin/rails server"
      exec("bin/rails server -p #{port}")
    end
  end
  
  desc "Kill any running Rails server on port 3000 (without restarting)"
  task :kill => :environment do
    port = 3000
    
    puts "🔍 Looking for Rails server on port #{port}..."
    
    # Find process using port 3000
    pid_output = `lsof -ti:#{port}`.strip
    
    if pid_output.present?
      pids = pid_output.split("\n")
      puts "📡 Found #{pids.length} process(es) on port #{port}: #{pids.join(', ')}"
      
      pids.each do |pid|
        begin
          # Get process info
          process_info = `ps -p #{pid} -o comm= 2>/dev/null`.strip
          puts "🔫 Killing PID #{pid} (#{process_info.present? ? process_info : 'unknown'})"
          
          # Kill the process
          system("kill -TERM #{pid}")
          sleep(2)
          
          # Check if it's still running and force kill if needed
          if `ps -p #{pid} 2>/dev/null`.present?
            puts "💥 Force killing PID #{pid}"
            system("kill -KILL #{pid}")
            sleep(1)
          end
          
          puts "✅ Successfully killed PID #{pid}"
        rescue => e
          puts "⚠️  Error killing PID #{pid}: #{e.message}"
        end
      end
      
      puts "✅ All Rails servers on port #{port} have been stopped"
    else
      puts "✅ No Rails server found on port #{port}"
    end
  end
  
  desc "Check what's running on port 3000"
  task :status => :environment do
    port = 3000
    
    puts "🔍 Checking port #{port} status..."
    
    # Find process using port 3000
    pid_output = `lsof -ti:#{port}`.strip
    
    if pid_output.present?
      pids = pid_output.split("\n")
      puts "📡 Found #{pids.length} process(es) on port #{port}:"
      
      pids.each do |pid|
        # Get detailed process info
        process_info = `ps -p #{pid} -o pid,ppid,comm,args 2>/dev/null`
        if process_info.present?
          puts process_info
        else
          puts "  PID #{pid} (process details unavailable)"
        end
      end
    else
      puts "✅ Port #{port} is free - no processes found"
    end
    
    # Also check if Rails server files exist
    puts ""
    puts "📂 Rails server files:"
    puts "  bin/dev: #{File.exist?('bin/dev') ? '✅ exists' : '❌ missing'}"
    puts "  bin/rails: #{File.exist?('bin/rails') ? '✅ exists' : '❌ missing'}"
    puts "  Procfile.dev: #{File.exist?('Procfile.dev') ? '✅ exists' : '❌ missing'}"
  end
end