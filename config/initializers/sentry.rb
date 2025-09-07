# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = "https://1e4446917e3cd5df623827f727788dcc@o4509945600868352.ingest.de.sentry.io/4509945602375760"
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # Add data like request headers and IP for users,
  # see https://docs.sentry.io/platforms/ruby/data-management/data-collected/ for more info
  config.send_default_pii = true
end


# Sentry.init do |config|
#  config.breadcrumbs_logger = [:active_support_logger]
#  config.dsn = ENV['SENTRY_DSN']
#  config.traces_sample_rate = 1.0
# end
