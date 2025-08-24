# Save this as lib/tasks/import_bangkok_data.rake

require 'pg'

namespace :data do
  desc "Import Bangkok OSM data into Points model"
  task import_bangkok: :environment do
    begin
      # Connection to Bangkok OSM database using environment variables
      bangkok_conn = PG.connect(
        host: ENV['PGHOST'] || 'localhost',
        dbname: 'bangkok_osm',
        user: ENV['PGUSER'],
        password: ENV['PGPASSWORD']
      )
      
      # Updated SQL query to include way field
      sql_query = <<-SQL
        SELECT
          osm_id,
          name,
          ST_Y(way) AS lat,
          ST_X(way) AS lon,
          way,
          tags
        FROM planet_osm_point
      SQL
      
      puts "Fetching data from Bangkok OSM database..."
      result = bangkok_conn.exec(sql_query)
      
      puts "Found #{result.ntuples} records. Importing..."
      
      result.each_with_index do |row, index|
        begin
          # Create Point record with the data including way
          Point.create!(
            osm_id: row['osm_id'],
            name: row['name'],
            lat: row['lat']&.to_f,
            lon: row['lon']&.to_f,
            way: row['way'],
            tags: row['tags']
          )
          
          # Show progress every 1000 records
          puts "Imported #{index + 1} records..." if (index + 1) % 1000 == 0
          
        rescue => e
          puts "Error importing record #{index + 1}: #{e.message}"
          puts "Row data: #{row.inspect}" if index < 3  # Show first few errors in detail
        end
      end
      
      puts "Import completed! Total Points: #{Point.count}"
      bangkok_conn.close
      
    rescue PG::Error => e
      puts "Database connection error: #{e.message}"
      puts "Make sure PGUSER and PGPASSWORD environment variables are set"
    end
  end
end