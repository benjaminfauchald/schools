# This module allows Capybara to share the database connection with the test suite
# This is necessary because Capybara runs the Rails app in a separate thread
class ActiveRecord::Base
  mattr_accessor :shared_connection
  @@shared_connection = nil

  def self.connection
    @@shared_connection || retrieve_connection
  end
end
