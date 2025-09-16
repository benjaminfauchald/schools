namespace :admin do
  desc "Create an admin user"
  task create_admin: :environment do
    email = ENV["ADMIN_EMAIL"] || "admin@example.com"
    password = ENV["ADMIN_PASSWORD"] || SecureRandom.urlsafe_base64(12)

    if User.exists?(email: email)
      puts "❌ User with email #{email} already exists!"
      user = User.find_by(email: email)
      if user.admin?
        puts "ℹ️  User is already an admin"
      else
        puts "ℹ️  Updating user role to admin..."
        user.update!(role: "admin")
        puts "✅ User role updated to admin"
      end
      exit 0
    end

    admin = User.create!(
      email: email,
      password: password,
      password_confirmation: password,
      role: "admin",
      confirmed_at: Time.current
    )

    puts "✅ Admin user created successfully!"
    puts "Email: #{admin.email}"
    puts "Password: #{password}"
    puts ""
    puts "You can now access the admin panel at: http://localhost:3000/admin"
    puts ""
    puts "⚠️  Please save this password securely. To reset it, run:"
    puts "   User.find_by(email: '#{email}').update!(password: 'new_password', password_confirmation: 'new_password')"
  end

  desc "List all admin users"
  task list_admins: :environment do
    admins = User.where(role: "admin")

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
    email = ENV["ADMIN_EMAIL"]
    new_password = ENV["NEW_PASSWORD"] || SecureRandom.urlsafe_base64(12)

    if email.blank?
      puts "❌ Please provide ADMIN_EMAIL environment variable"
      puts "Usage: ADMIN_EMAIL=admin@example.com rake admin:reset_password"
      exit 1
    end

    admin = User.find_by(email: email)

    if admin.nil?
      puts "❌ No user found with email: #{email}"
      exit 1
    end

    unless admin.admin?
      puts "❌ User #{email} is not an admin"
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
