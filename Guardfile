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
guard :rspec, cmd: "bundle exec rspec" do
  # run changed spec (including any .rb file in spec/)
  watch(%r{^spec/.+\.rb$}) { 'spec' }

  # model -> model spec
  watch(%r{^app/models/(.+)\.rb$})     { |m| "spec/models/#{m[1]}_spec.rb" }

  # controller -> controller spec
  watch(%r{^app/controllers/(.+)_controller\.rb$}) { |m| "spec/requests/#{m[1]}_spec.rb" }

  # views/partials/helpers/components -> feature/system/request specs as you prefer
  watch(%r{^app/views/(.+)\.(erb|haml|slim)$})     { "spec/system" }
  watch(%r{^app/helpers/(.+)\.rb$})                { "spec/helpers" }
  watch(%r{^app/(view_components|components)/(.+)\.rb$}) { "spec/components" }
  watch(%r{^app/(view_components|components)/(.+)\.(erb|haml|slim)$}) { "spec" }

  # Stimulus controllers (adjust path if you use js/ts)
  watch(%r{^app/javascript/controllers/(.+)\.(js|ts)$}) { "spec/system" }

  # Configuration files that might affect tests
  watch(%r{^config/routes\.rb$}) { 'spec' }
  watch(%r{^config/application\.rb$}) { 'spec' }
  watch(%r{^config/environments/test\.rb$}) { 'spec' }
  watch(%r{^config/initializers/.+\.rb$}) { 'spec' }

  # Rake tasks that might affect application logic
  watch(%r{^lib/tasks/.+\.rake$}) { 'spec' }

  # Database changes
  watch(%r{^db/migrate/.+\.rb$}) { 'spec' }
  watch(%r{^db/schema\.rb$}) { 'spec' }
  watch(%r{^db/seeds\.rb$}) { 'spec' }

  # Gemfile changes
  watch('Gemfile') { 'spec' }
  watch('Gemfile.lock') { 'spec' }

  # Mailers and email templates
  watch(%r{^app/mailers/.+\.rb$}) { 'spec' }
  watch(%r{^app/views/.+_mailer/.+\.(erb|html|text)$}) { 'spec' }

  # Jobs (if you add background jobs)
  watch(%r{^app/jobs/.+\.rb$}) { 'spec' }

  # Services/POROs in app/services
  watch(%r{^app/services/.+\.rb$}) { 'spec' }

  # Locale files (since you have i18n)
  watch(%r{^config/locales/.+\.yml$}) { 'spec/system' }

  # run everything if core helpers change
  watch('spec/spec_helper.rb') { 'spec' }
  watch('spec/rails_helper.rb') { 'spec' }
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
