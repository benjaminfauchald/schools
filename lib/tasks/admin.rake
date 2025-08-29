namespace :admin do
  desc "Create an admin user"
  task create_admin: :environment do
    email = ENV['ADMIN_EMAIL'] || 'admin@example.com'
    password = ENV['ADMIN_PASSWORD'] || SecureRandom.urlsafe_base64(12)
    
    if AdminUser.exists?(email: email)
      puts "❌ Admin user with email #{email} already exists!"
      exit 1
    end
    
    admin = AdminUser.create!(
      email: email,
      password: password,
      password_confirmation: password
    )
    
    puts "✅ Admin user created successfully!"
    puts "Email: #{admin.email}"
    puts "Password: #{password}"
    puts ""
    puts "You can now access the admin panel at: http://localhost:3000/admin"
    puts ""
    puts "⚠️  Please save this password securely. To reset it, run:"
    puts "   AdminUser.find_by(email: '#{email}').update!(password: 'new_password', password_confirmation: 'new_password')"
  end
  
  desc "List all admin users"
  task list_admins: :environment do
    admins = AdminUser.all
    
    if admins.empty?
      puts "No admin users found. Run 'rake admin:create_admin' to create one."
    else
      puts "Admin users:"
      admins.each do |admin|
        puts "  - #{admin.email} (created: #{admin.created_at.strftime('%Y-%m-%d')})"
      end
    end
  end
  
  desc "Reset admin password"
  task reset_password: :environment do
    email = ENV['ADMIN_EMAIL']
    new_password = ENV['NEW_PASSWORD'] || SecureRandom.urlsafe_base64(12)
    
    if email.blank?
      puts "❌ Please provide ADMIN_EMAIL environment variable"
      puts "Usage: ADMIN_EMAIL=admin@example.com rake admin:reset_password"
      exit 1
    end
    
    admin = AdminUser.find_by(email: email)
    
    if admin.nil?
      puts "❌ No admin user found with email: #{email}"
      exit 1
    end
    
    admin.update!(
      password: new_password,
      password_confirmation: new_password
    )
    
    puts "✅ Password reset successfully!"
    puts "Email: #{admin.email}"
    puts "New Password: #{new_password}"
    puts ""
    puts "⚠️  Please save this password securely."
  end
end