RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  config.before(:each, type: :system) do
    DatabaseCleaner.strategy = :truncation
  end

  config.after(:each, type: :system) do
    DatabaseCleaner.strategy = :transaction
  end
end
