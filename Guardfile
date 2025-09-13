# A sample Guardfile
# More info at https://github.com/guard/guard#readme

## Uncomment and set this to only include directories you want to watch
# directories %w(app lib config test spec features) \
#  .select{|d| Dir.exist?(d) ? d : UI.warning("Directory #{d} does not exist")}

## Note: if you are using the `directories` clause above and you are not
## watching the project directory ('.'), then you will want to move
## the Guardfile to a watched dir and symlink it back, e.g.
#
#  $ mkdir config
#  $ mv Guardfile config/
#  $ ln -s config/Guardfile .
#
# and, you'll have to watch "config/Guardfile" instead of "Guardfile"

# Note: The cmd option is now required due to the increasing number of ways
#       rspec may be run, below are examples of the most common uses.
#  * bundler: 'bundle exec rspec'
#  * bundler binstubs: 'bin/rspec'
#  * spring: 'bin/rspec' (This will use spring if running and you have
#                          installed the spring binstubs per the docs)
#  * zeus: 'zeus rspec' (requires the server to be started separately)
#  * 'just' rspec: 'rspec'

# Guardfile

# macOS notifications (green=pass, red=fail)
notification :terminal_notifier

# Faster file watching on macOS
guard :rspec, cmd: "bundle exec rspec", all_on_start: false, all_after_pass: false do
  # run the specific spec that changed (not all specs!)
  watch(%r{^spec/.+_spec\.rb$})

  # model -> model spec
  watch(%r{^app/models/(.+)\.rb$})     { |m| "spec/models/#{m[1]}_spec.rb" }

  # controller -> controller spec
  watch(%r{^app/controllers/(.+)_controller\.rb$}) { |m| "spec/requests/#{m[1]}_spec.rb" }

  # views/partials/helpers/components -> feature/system/request specs as you prefer
  watch(%r{^app/views/(.+)\.(erb|haml|slim)$})     { |m| "spec/system" }
  watch(%r{^app/helpers/(.+)\.rb$})                { |m| "spec/helpers/#{m[1]}_helper_spec.rb" }
  watch(%r{^app/(view_components|components)/(.+)\.rb$}) { |m| "spec/components/#{m[2]}_spec.rb" }
  watch(%r{^app/(view_components|components)/(.+)\.(erb|haml|slim)$}) { |m| "spec/components" }

  # Stimulus controllers (adjust path if you use js/ts)
  watch(%r{^app/javascript/controllers/(.+)\.(js|ts)$}) { "spec/system" }

  # Configuration files that might affect tests - run only routing specs for routes
  watch(%r{^config/routes\.rb$}) { 'spec/routing' }
  watch(%r{^config/application\.rb$}) { 'spec/models' }  # Run fast unit tests
  watch(%r{^config/environments/test\.rb$}) { 'spec/models' }  # Run fast unit tests
  watch(%r{^config/initializers/.+\.rb$}) { 'spec/models' }  # Run fast unit tests

  # Rake tasks that might affect application logic
  watch(%r{^lib/tasks/.+\.rake$}) { 'spec/models' }

  # Database changes - run model specs as they're most affected
  watch(%r{^db/migrate/.+\.rb$}) { 'spec/models' }
  watch(%r{^db/schema\.rb$}) { 'spec/models' }
  watch(%r{^db/seeds\.rb$}) { 'spec/models' }

  # Gemfile changes - don't auto-run tests, just notify
  watch('Gemfile') { nil }
  watch('Gemfile.lock') { nil }

  # Mailers and email templates
  watch(%r{^app/mailers/.+\.rb$}) { |m| "spec/mailers" }
  watch(%r{^app/views/.+_mailer/.+\.(erb|html|text)$}) { "spec/mailers" }

  # Jobs (if you add background jobs)
  watch(%r{^app/jobs/.+\.rb$}) { |m| "spec/jobs" }

  # Services/POROs in app/services
  watch(%r{^app/services/.+\.rb$}) { |m| "spec/services" }

  # Locale files (since you have i18n)
  watch(%r{^config/locales/.+\.yml$}) { 'spec/system' }

  # run model tests if core helpers change (faster feedback)
  watch('spec/spec_helper.rb') { 'spec/models' }
  watch('spec/rails_helper.rb') { 'spec/models' }
end



# guard :rspec, cmd: "bundle exec rspec" do
#   require "guard/rspec/dsl"
#   dsl = Guard::RSpec::Dsl.new(self)

#   # Feel free to open issues for suggestions and improvements

#   # RSpec files
#   rspec = dsl.rspec
#   watch(rspec.spec_helper) { rspec.spec_dir }
#   watch(rspec.spec_support) { rspec.spec_dir }
#   watch(rspec.spec_files)

#   # Ruby files
#   ruby = dsl.ruby
#   dsl.watch_spec_files_for(ruby.lib_files)

#   # Rails files
#   rails = dsl.rails(view_extensions: %w(erb haml slim))
#   dsl.watch_spec_files_for(rails.app_files)
#   dsl.watch_spec_files_for(rails.views)

#   watch(rails.controllers) do |m|
#     [
#       rspec.spec.call("routing/#{m[1]}_routing"),
#       rspec.spec.call("controllers/#{m[1]}_controller"),
#       rspec.spec.call("acceptance/#{m[1]}")
#     ]
#   end

#   # Rails config changes
#   watch(rails.spec_helper)     { rspec.spec_dir }
#   watch(rails.routes)          { "#{rspec.spec_dir}/routing" }
#   watch(rails.app_controller)  { "#{rspec.spec_dir}/controllers" }

#   # Capybara features specs
#   watch(rails.view_dirs)     { |m| rspec.spec.call("features/#{m[1]}") }
#   watch(rails.layouts)       { |m| rspec.spec.call("features/#{m[1]}") }

#   # Turnip features and steps
#   watch(%r{^spec/acceptance/(.+)\.feature$})
#   watch(%r{^spec/acceptance/steps/(.+)_steps\.rb$}) do |m|
#     Dir[File.join("**/#{m[1]}.feature")][0] || "spec/acceptance"
#   end
# end
