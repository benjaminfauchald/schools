# Database Cleaner Configuration for proper test isolation
RSpec.configure do |config|
  # Initial suite cleanup
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation, except: %w[ar_internal_metadata schema_migrations])
  end

  # Model specs - use truncation for complete isolation
  config.before(:each, type: :model) do
    DatabaseCleaner.strategy = :truncation, {
      except: %w[ar_internal_metadata schema_migrations],
      pre_count: false,
      cache_tables: false,
      reset_ids: true
    }
    DatabaseCleaner.start
  end
  
  config.after(:each, type: :model) do
    DatabaseCleaner.clean
    ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connected?
    FactoryBot.reload if defined?(FactoryBot)
    FactoryBot.rewind_sequences if defined?(FactoryBot)
  end
  
  # System specs - use deletion strategy to avoid deadlocks
  config.before(:each, type: :system) do
    DatabaseCleaner.strategy = :deletion, {
      except: %w[ar_internal_metadata schema_migrations]
    }
    DatabaseCleaner.start
  end
  
  config.after(:each, type: :system) do
    DatabaseCleaner.clean
  end
  
  # Request specs - use transaction when possible
  config.before(:each, type: :request) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.start
  end
  
  config.after(:each, type: :request) do
    DatabaseCleaner.clean
  end
  
  # Other specs - use transaction
  config.before(:each) do |example|
    unless [:model, :system, :request].include?(example.metadata[:type]) || example.metadata[:js]
      DatabaseCleaner.strategy = :transaction
      DatabaseCleaner.start
    end
  end
  
  config.after(:each) do |example|
    unless [:model, :system, :request].include?(example.metadata[:type])
      DatabaseCleaner.clean
    end
  end
end