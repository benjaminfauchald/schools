class CreateVectorDatabaseSetup < ActiveRecord::Migration[8.0]
  def up
    # Enable the vector extension
    # Note: pgvector extension needs to be installed manually
    # Run: CREATE EXTENSION vector; in your PostgreSQL database
    begin
      enable_extension 'vector'
    rescue PG::UndefinedFile => e
      Rails.logger.warn "pgvector extension not found. Please install it manually:"
      Rails.logger.warn "1. Install pgvector: brew install pgvector"
      Rails.logger.warn "2. Connect to your database and run: CREATE EXTENSION vector;"
      raise e
    end
  end

  def down
    disable_extension 'vector' if extension_enabled?('vector')
  end
end
