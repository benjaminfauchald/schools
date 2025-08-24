# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ruby on Rails 8.0.2 application for managing OpenStreetMap (OSM) geographic data, specifically focusing on points of interest in Bangkok including schools and amenities. The application integrates with Google Places API to enrich OSM data and uses PostGIS for spatial database operations.



  Backup Usage Examples:

  # Restore latest backup
  rails data:backup

  # Restore latest backup
  rails data:restore

  # Restore specific backup
  rails data:restore_from[schools_development_20250824_150351.sql]

  # List available backups
  rails data:list_backups

  # Create backup before restore
  rails data:backup



Now working:

  - ✅ ViewComponent previews are accessible at
  /rails/view_components
  - ✅ ExampleComponent is loaded and available
  - ✅ Preview shows Flowbite-styled card component
  - ✅ Component generation works with bin/rails generate
  view_component:component
  - ✅ Preview generation works with bin/rails generate
  view_component:preview


## Development Commands

### Setup
```bash
bin/setup                              # Initial setup (install dependencies, create database)
bin/rails db:create db:migrate        # Database setup
bundle install                        # Install Ruby dependencies
```

### Development Server
```bash
bin/dev                                # Start development server with Tailwind CSS watching (preferred)
bin/rails server                      # Start Rails server only
foreman start -f Procfile.dev         # Alternative development server with CSS watching
```

### Data Import Tasks
```bash
bin/rails data:import_bangkok          # Import OSM data from Bangkok database
bin/rails data:import_points_to_places # Enrich Points with Google Places API data
bin/rails data:osm_stats              # Display comprehensive OSM data statistics
```

### Database Backup
```bash
bin/rails data:backup                 # Create database backup
bin/rails data:backup_with_name[filename] # Create backup with custom filename
bin/rails data:list_backups           # List all backups
bin/rails data:clean_backups          # Clean old backups (keeps last 5)
```

### Code Quality & Security
```bash
bin/rubocop                           # Run code style checks
bin/brakeman                          # Security vulnerability scanning
```

### Asset Management
```bash
bin/rails tailwindcss:build          # Build Tailwind CSS
bin/rails tailwindcss:watch          # Watch and rebuild CSS on changes
bin/rails assets:precompile           # Precompile assets for production
```

### ViewComponent Development
```bash
bin/rails generate view_component:component [ComponentName] # Generate new component
bin/rails generate view_component:preview [ComponentName]   # Generate component preview
```

## Architecture & Key Components

### Database Models
- **Point**: Central model storing OSM point-of-interest data with comprehensive geographic and metadata fields
- **Place**: Google Places API data linked to Points, providing business information like ratings and hours
- **School**: Extended Place model specifically for educational institutions
- Uses PostGIS adapter for spatial database operations with PostgreSQL

### Geographic Data Stack
- **PostGIS**: Spatial database extension for geographic queries and indexing
- **RGeo**: Ruby library for geometric operations and spatial data handling
- Comprehensive OSM field mapping including multilingual names and Bangkok-specific address structure

### Admin Interface
- **Administrate** gem provides admin panel at `/admin/`
- Full CRUD operations for Points and Places with search and filtering capabilities

### Frontend Technologies
- **Hotwire** (Turbo + Stimulus) for reactive frontend behavior
- **Tailwind CSS** for styling with live reloading via `tailwindcss:watch`
- **Flowbite** UI component library for enhanced Tailwind components
- **ViewComponent** for component-based view architecture
- **ImportMap** for JavaScript dependency management

### Component Architecture
- **ViewComponent**: Components stored in `app/components/` directory
- Component previews available in development at `/rails/view_components`
- Preview files located in `test/components/previews/`
- Components follow Rails conventions with `.rb` class and `.html.erb` template
- ViewComponent engine mounted at `/rails/view_components` in development only

### UI Framework Stack
- **Tailwind CSS**: Utility-first CSS framework configured in `tailwind.config.js`
- **Flowbite**: Pre-built Tailwind components available via CDN
- Flowbite CSS: `https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.min.css`
- Flowbite JS: `https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.min.js`
- Configuration supports charts and interactive components

### Data Processing Pipeline
- Custom Rake tasks in `lib/tasks/` for data import and processing
- Automated OSM to Google Places enrichment workflow
- Comprehensive error handling and progress tracking for data operations

## File Structure

### Component Organization
```
app/components/               # ViewComponent classes and templates
spec/components/previews/     # Component previews for development
```

### Asset Structure
```
app/assets/tailwind/          # Tailwind CSS source files
app/assets/builds/tailwind/   # Compiled Tailwind output
app/javascript/               # JavaScript modules and controllers
```

### Configuration Files
```
config/importmap.rb           # JavaScript module imports including Flowbite
tailwind.config.js            # Tailwind CSS and Flowbite configuration
config/initializers/view_component.rb  # ViewComponent configuration
```

## External Dependencies

### Required Environment Variables
- Database connection variables: `PGHOST`, `PGUSER`, `PGPASSWORD` for OSM data import
- `SCHOOLS_DATABASE_PASSWORD` for production database access
- `GOOGLE_PLACES_API_KEY` for Google Places API integration

### External Services
- Bangkok OSM database for point-of-interest import
- Google Places API for business data enrichment
- Flowbite CDN for UI components

## Component Development Workflow

### Creating New Components
1. Generate component: `bin/rails generate view_component:component [ComponentName]`
2. Implement logic in `app/components/[component_name].rb`
3. Create template in `app/components/[component_name].html.erb`
4. Generate preview: `bin/rails generate view_component:preview [ComponentName]`
5. Test in browser at `/rails/view_components`

### Flowbite Integration
- All Flowbite components available in templates
- JavaScript initialization handled automatically via importmap
- Custom Tailwind classes can extend Flowbite components
- Charts and interactive components enabled in configuration

## ⚠️ CRITICAL DATABASE PROTECTION RULES ⚠️

### 🛡️ **NEVER DELETE CORE DATA MODELS**

**ABSOLUTELY FORBIDDEN OPERATIONS:**
- `Place.delete_all` or `Place.destroy_all` 
- `Point.delete_all` or `Point.destroy_all`
- `School.delete_all` or `School.destroy_all` (unless explicitly confirmed test data)
- Any bulk deletion of Places, Points, or Schools without explicit user confirmation
- Dropping or truncating places, points, or schools tables
- Running destructive migrations without backups

**BEFORE ANY DATA DELETION:**
1. **ALWAYS create a database backup first**: `bin/rails data:backup` 
2. **Ask the user explicitly** for confirmation before deleting ANY Places or Points data
3. **Use targeted deletion only** - never delete all records from core models
4. **Show exact count** of records that would be deleted before proceeding

### 📋 **REQUIRED SAFETY CHECKS**

**For any task involving data deletion:**
```ruby
# ✅ REQUIRED PATTERN - Always check first
puts "⚠️  WARNING: About to delete data"
puts "Records to delete: #{records_to_delete.count}"  
puts "Sample records:"
records_to_delete.limit(3).each { |r| puts "  - #{r.name || r.id}" }
puts ""
print "Continue? Type 'DELETE CONFIRMED' to proceed: "
confirmation = STDIN.gets.chomp
unless confirmation == 'DELETE CONFIRMED'
  puts "❌ Operation cancelled"
  exit
end
```

**For cleanup tasks:**
- Always implement `--dry-run` mode first
- Show detailed preview of what would be deleted
- Require explicit confirmation for actual deletion
- Create backups before destructive operations

### 🔒 **DATABASE BACKUP REQUIREMENTS**

**Before ANY destructive operation:**
```bash
# Create timestamped backup
bin/rails data:backup
```

**Backup should be created for:**
- Any rake task that deletes data
- Schema changes
- Data migrations  
- Bulk updates to core models

### 🏷️ **TEST DATA IDENTIFICATION**

**Safe test data deletion only when:**
- Records have explicit `test_data: true` markers in JSON fields
- Records have test-specific naming patterns (e.g., "Test School Campus YYYY_MM_DD")
- Records are in dedicated test namespaces
- User has confirmed these are test records

**Never assume data is "test data" based on:**
- Creation date alone
- Similar naming patterns
- Bulk creation patterns
- Database seeding operations

### 🚨 **EMERGENCY RECOVERY**

**If data is accidentally deleted:**
1. Immediately stop all operations
2. Check `/tmp/backups/` for recent backups
3. Restore from most recent backup before deletion:
   ```bash
   psql schools_development < /tmp/backups/latest_backup.sql
   ```
4. Notify user of recovery status

### 🧪 **SAFE DEVELOPMENT PATTERNS**

**For rake tasks that modify data:**
```ruby
# ✅ SAFE PATTERN
task cleanup_test_data: :environment do
  # 1. Create backup first
  puts "📄 Creating backup before cleanup..."
  system('bin/rails data:backup')
  
  # 2. Show what will be deleted
  test_records = Model.where("test_condition")
  puts "⚠️  Will delete #{test_records.count} test records"
  test_records.limit(3).each { |r| puts "  - #{r.name}" }
  
  # 3. Require explicit confirmation
  print "Type 'DELETE CONFIRMED' to proceed: "
  confirmation = STDIN.gets.chomp
  unless confirmation == 'DELETE CONFIRMED'
    puts "❌ Operation cancelled"
    exit
  end
  
  # 4. Proceed with deletion
  test_records.destroy_all
end
```

---

## Important Notes

### No Testing Framework
- The application currently has no test suite configured (neither RSpec nor Minitest)
- Consider adding tests before making significant changes
- ViewComponent preview system can serve as basic component testing

### Spatial Database Requirements  
- PostgreSQL with PostGIS extension is required for spatial operations
- Database adapter is configured as `postgis` rather than standard `postgresql`

### Production Deployment
- Docker containerization available with multi-stage builds
- Kamal deployment configuration included
- Separate databases for cache, queue, and cable operations in production

### Development Workflow
- Use `bin/dev` for development to ensure CSS compilation
- Run data import tasks to populate the database with OSM data
- Access admin interface at `/admin/` for data management
- Check data import statistics with `data:osm_stats` task
- View component previews at `/rails/view_components` in development
- Flowbite components automatically initialized on page load