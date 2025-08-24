# Save this as lib/tasks/import_bangkok_data.rake

require 'pg'

namespace :data do
  desc "Import Bangkok OSM data with all common fields into Points model"
  task import_bangkok: :environment do
    begin
      # Connection to Bangkok OSM database using environment variables
      bangkok_conn = PG.connect(
        host: ENV['PGHOST'] || 'localhost',
        dbname: 'bangkok_osm',
        user: ENV['PGUSER'],
        password: ENV['PGPASSWORD']
      )
      
      # First, check what columns are available in the source table
      puts "Checking available columns in planet_osm_point..."
      column_check = bangkok_conn.exec(<<-SQL
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_name = 'planet_osm_point' 
        AND table_schema = 'public'
        ORDER BY ordinal_position;
      SQL
      )
      
      available_columns = column_check.map { |row| row['column_name'] }
      puts "Found #{available_columns.length} columns in source table"
      
      # Map Point model fields to OSM columns/tags
      field_mappings = {
        # Core fields (always present)
        'osm_id' => { type: :column, source: 'osm_id' },
        'name' => { type: :column, source: 'name' },
        'lat' => { type: :function, source: 'ST_Y(way)' },
        'lon' => { type: :function, source: 'ST_X(way)' },
        'way' => { type: :column, source: 'way' },
        'tags' => { type: :column, source: 'tags' },
        
        # Direct column mappings (if they exist as columns)
        'amenity' => { type: :column, source: 'amenity' },
        'shop' => { type: :column, source: 'shop' },
        'tourism' => { type: :column, source: 'tourism' },
        'leisure' => { type: :column, source: 'leisure' },
        'office' => { type: :column, source: 'office' },
        'craft' => { type: :column, source: 'craft' },
        'healthcare' => { type: :column, source: 'healthcare' },
        'emergency' => { type: :column, source: 'emergency' },
        'public_transport' => { type: :column, source: 'public_transport' },
        'highway' => { type: :column, source: 'highway' },
        'railway' => { type: :column, source: 'railway' },
        'aeroway' => { type: :column, source: 'aeroway' },
        'waterway' => { type: :column, source: 'waterway' },
        'natural' => { type: :column, source: 'natural' },
        'landuse' => { type: :column, source: 'landuse' },
        'building' => { type: :column, source: 'building' },
        'religion' => { type: :column, source: 'religion' },
        'denomination' => { type: :column, source: 'denomination' },
        'cuisine' => { type: :column, source: 'cuisine' },
        'brand' => { type: :column, source: 'brand' },
        'network' => { type: :column, source: 'network' },
        'operator' => { type: :column, source: 'operator' },
        'phone' => { type: :column, source: 'phone' },
        'website' => { type: :column, source: 'website' },
        'email' => { type: :column, source: 'email' },
        'opening_hours' => { type: :column, source: 'opening_hours' },
        'access' => { type: :column, source: 'access' },
        'ele' => { type: :column, source: 'ele' },
        'capacity' => { type: :column, source: 'capacity' },
        'building_levels' => { type: :column, source: 'building:levels' },
        'wheelchair' => { type: :column, source: 'wheelchair' },
        
        # Tag-based mappings (extracted from hstore tags column)
        'name_en' => { type: :tag, source: 'name:en' },
        'name_th' => { type: :tag, source: 'name:th' },
        'alt_name' => { type: :tag, source: 'alt_name' },
        'official_name' => { type: :tag, source: 'official_name' },
        'addr_housenumber' => { type: :tag, source: 'addr:housenumber' },
        'addr_street' => { type: :tag, source: 'addr:street' },
        'addr_city' => { type: :tag, source: 'addr:city' },
        'addr_postcode' => { type: :tag, source: 'addr:postcode' },
        'addr_country' => { type: :tag, source: 'addr:country' },
        'addr_district' => { type: :tag, source: 'addr:district' },
        'addr_province' => { type: :tag, source: 'addr:province' },
        'addr_subdistrict' => { type: :tag, source: 'addr:subdistrict' },
        'school_type' => { type: :tag, source: 'school:type' },
        'operator_type' => { type: :tag, source: 'operator:type' }
      }
      
      # Build SELECT clause based on available columns
      select_clauses = []
      import_fields = []
      
      field_mappings.each do |field_name, mapping|
        case mapping[:type]
        when :column
          if available_columns.include?(mapping[:source])
            # Quote reserved words like 'natural', 'access', etc.
            quoted_source = %w[natural access].include?(mapping[:source]) ? "\"#{mapping[:source]}\"" : mapping[:source]
            select_clauses << "#{quoted_source} AS #{field_name}"
            import_fields << field_name
          end
        when :function
          select_clauses << "#{mapping[:source]} AS #{field_name}"
          import_fields << field_name
        when :tag
          if available_columns.include?('tags')
            select_clauses << "tags->'#{mapping[:source]}' AS #{field_name}"
            import_fields << field_name
          end
        end
      end
      
      # Build the complete SQL query
      sql_query = <<-SQL
        SELECT #{select_clauses.join(",\n               ")}
        FROM planet_osm_point
        ORDER BY osm_id
      SQL
      
      puts "Built query with #{select_clauses.length} fields:"
      puts "Fields to import: #{import_fields.join(', ')}"
      puts "\nExecuting query..."
      
      result = bangkok_conn.exec(sql_query)
      puts "Found #{result.ntuples} records. Starting import..."
      
      # Import with progress tracking and error handling
      imported_count = 0
      updated_count = 0
      error_count = 0
      
      result.each_with_index do |row, index|
        begin
          # Prepare attributes hash
          attributes = {}
          
          # Process each field with appropriate type conversion
          row.each do |field_name, value|
            case field_name
            when 'lat', 'lon'
              attributes[field_name] = value&.to_f
            when 'osm_id', 'ele', 'capacity', 'building_levels'
              attributes[field_name] = value&.to_i
            else
              # String fields - clean up empty values
              attributes[field_name] = value.present? ? value : nil
            end
          end
          
          # Create or update Point record
          point = Point.find_by(osm_id: attributes['osm_id'])
          
          if point
            # Update existing record
            point.update!(attributes.except('osm_id'))
            updated_count += 1
          else
            # Create new record
            point = Point.create!(attributes)
            imported_count += 1
          end
          
          # Show progress every 1000 records
          if (index + 1) % 1000 == 0
            puts "Processed #{index + 1}/#{result.ntuples} records (#{imported_count} created, #{updated_count} updated, #{error_count} errors)..."
          end
          
        rescue => e
          error_count += 1
          if error_count <= 5  # Show first few errors in detail
            puts "Error importing record #{index + 1}: #{e.message}"
            puts "OSM ID: #{row['osm_id']}, Name: #{row['name']}"
          elsif error_count == 6
            puts "... (suppressing further error details)"
          end
        end
      end
      
      bangkok_conn.close
      
      # Final summary report
      puts "\n" + "="*80
      puts "IMPORT COMPLETED!"
      puts "="*80
      puts "Total records in source: #{result.ntuples}"
      puts "Successfully created: #{imported_count}"
      puts "Successfully updated: #{updated_count}"
      puts "Errors: #{error_count}"
      puts "Total Points in database: #{Point.count}"
      puts "="*80
      
      # Show statistics about imported data
      puts "\n📊 Import Statistics:"
      puts "Records with names: #{Point.where.not(name: [nil, '']).count}"
      puts "Records with amenities: #{Point.where.not(amenity: [nil, '']).count}"
      puts "Records with addresses: #{Point.where.not(addr_street: [nil, '']).count}"
      puts "Records with phone numbers: #{Point.where.not(phone: [nil, '']).count}"
      puts "Records with websites: #{Point.where.not(website: [nil, '']).count}"
      puts "Schools: #{Point.where(amenity: 'school').count}"
      puts "Restaurants: #{Point.where(amenity: ['restaurant', 'cafe', 'fast_food']).count}"
      puts "Shops: #{Point.where.not(shop: [nil, '']).count}"
      puts "Tourism sites: #{Point.where.not(tourism: [nil, '']).count}"
      
      # Show top categories
      puts "\n🏢 Top 10 Amenity Types:"
      Point.where.not(amenity: [nil, ''])
           .group(:amenity)
           .count
           .sort_by { |k, v| -v }
           .first(10)
           .each { |amenity, count| puts "  #{amenity}: #{count}" }
      
      puts "\n🛍️  Top 5 Shop Types:"
      Point.where.not(shop: [nil, ''])
           .group(:shop)
           .count
           .sort_by { |k, v| -v }
           .first(5)
           .each { |shop_type, count| puts "  #{shop_type}: #{count}" }
      
      puts "\n🏛️  Top 5 Tourism Types:"
      Point.where.not(tourism: [nil, ''])
           .group(:tourism)
           .count
           .sort_by { |k, v| -v }
           .first(5)
           .each { |tourism_type, count| puts "  #{tourism_type}: #{count}" }
      
    rescue PG::Error => e
      puts "Database connection error: #{e.message}"
      puts "Make sure PGUSER and PGPASSWORD environment variables are set"
      puts "Connection details:"
      puts "  Host: #{ENV['PGHOST'] || 'localhost'}"
      puts "  Database: bangkok_osm"
      puts "  User: #{ENV['PGUSER'] || '(not set)'}"
    rescue => e
      puts "Unexpected error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
  
  desc "Show comprehensive OSM data statistics"
  task osm_stats: :environment do
    puts "📊 Bangkok OSM Data Statistics"
    puts "="*50
    
    total = Point.count
    puts "Total points: #{total.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    
    # Field completion rates
    important_fields = {
      'name' => 'Names',
      'amenity' => 'Amenities', 
      'addr_street' => 'Street addresses',
      'phone' => 'Phone numbers',
      'website' => 'Websites',
      'opening_hours' => 'Opening hours',
      'cuisine' => 'Cuisine types',
      'brand' => 'Brands',
      'building' => 'Buildings'
    }
    
    puts "\n📋 Field Completion Rates:"
    important_fields.each do |field, description|
      if Point.column_names.include?(field)
        count = Point.where.not(field => [nil, '']).count
        percentage = (count.to_f / total * 100).round(1)
        puts "  #{description}: #{count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}/#{total.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} (#{percentage}%)"
      end
    end
    
    # Category breakdowns
    categories = ['amenity', 'shop', 'tourism', 'leisure', 'office']
    categories.each do |category|
      if Point.column_names.include?(category)
        count = Point.where.not(category => [nil, '']).count
        next if count == 0
        
        puts "\n🏷️  #{category.capitalize} (#{count} total):"
        Point.where.not(category => [nil, ''])
             .group(category)
             .count
             .sort_by { |k, v| -v }
             .first(5)
             .each { |type, count| puts "  #{type}: #{count}" }
      end
    end
    
    # Address distribution
    if Point.column_names.include?('addr_district')
      puts "\n🏘️  Top Districts by POI count:"
      Point.where.not(addr_district: [nil, ''])
           .group(:addr_district)
           .count
           .sort_by { |k, v| -v }
           .first(10)
           .each { |district, count| puts "  #{district}: #{count}" }
    end
  end
end