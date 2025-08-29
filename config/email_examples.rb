# EMAIL CONFIGURATION EXAMPLES
# Add these to your production.rb or configure via environment variables

# Option 1: Gmail SMTP (Simple for small projects)
# config.action_mailer.delivery_method = :smtp
# config.action_mailer.smtp_settings = {
#   address: 'smtp.gmail.com',
#   port: 587,
#   domain: 'yourdomain.com',
#   user_name: ENV['GMAIL_USERNAME'],
#   password: ENV['GMAIL_APP_PASSWORD'], # Use App Password, not regular password
#   authentication: 'plain',
#   enable_starttls_auto: true
# }

# Option 2: SendGrid (Popular production choice)
# config.action_mailer.delivery_method = :smtp
# config.action_mailer.smtp_settings = {
#   address: 'smtp.sendgrid.net',
#   port: 587,
#   domain: 'yourdomain.com',
#   user_name: 'apikey',
#   password: ENV['SENDGRID_API_KEY'],
#   authentication: 'plain',
#   enable_starttls_auto: true
# }

# Option 3: Mailgun
# config.action_mailer.delivery_method = :smtp
# config.action_mailer.smtp_settings = {
#   address: 'smtp.mailgun.org',
#   port: 587,
#   domain: ENV['MAILGUN_DOMAIN'],
#   user_name: ENV['MAILGUN_USERNAME'],
#   password: ENV['MAILGUN_PASSWORD'],
#   authentication: 'plain',
#   enable_starttls_auto: true
# }

# Option 4: AWS SES
# gem 'aws-ses', '~> 0.7.1' # Add to Gemfile
# config.action_mailer.delivery_method = :ses
# config.action_mailer.ses_settings = {
#   region: ENV['AWS_REGION'] || 'us-east-1',
#   access_key_id: ENV['AWS_ACCESS_KEY_ID'],
#   secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
# }

# Production settings (add to production.rb):
# config.action_mailer.default_url_options = { host: 'yourdomain.com', protocol: 'https' }
# config.action_mailer.perform_deliveries = true
# config.action_mailer.raise_delivery_errors = true
# config.action_mailer.perform_caching = false