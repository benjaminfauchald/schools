# CLAUDE.md

DONT KILL OR START RAILS DEVELOPMENT SERVER JUST ASK YOUR TO RESTART SERVER
DO NOT pkill -f "rails server" or kill any rails server!


This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ruby on Rails 8.0.2 application for managing OpenStreetMap (OSM) geographic data, specifically focusing on points of interest in Bangkok including schools and amenities. The application integrates with Google Places API to enrich OSM data and uses PostGIS for spatial database operations.

**Facebook OAuth & Webhooks**: The application includes complete Facebook OAuth integration for user authentication and GDPR-compliant webhook endpoints for data deletion and deauthorization requests. See `FACEBOOK_WEBHOOK_SETUP.md` for configuration details.


When you use a library, API or gem, first check the docs with MCP server ref and context7

## JavaScript Console Debugging & Debug Mode

The application includes a comprehensive debugging system for JavaScript development:

### Debug Mode Configuration
- **Environment Variable**: `DEBUG_MODE=on` in `.env` file controls debug logging
- **Meta Tag Detection**: `<meta name="debug-mode" content="true/false">` in layout for JS access
- **JavaScript Detection**: `const debugMode = document.querySelector('meta[name="debug-mode"]')?.content === 'true'`

### Console Debugging Best Practices
1. **Conditional Logging**: Only log debug messages when `DEBUG_MODE=on`
   ```javascript
   if (debugMode) {
     console.log('🎯 [DEBUG] Debug message here', data);
   }
   ```

2. **Structured Debug Messages**: Use consistent emoji prefixes and clear descriptions
   ```javascript
   console.log("🎯 Form submit intercepted", event)
   console.log("🗺️ [GOOGLE MAPS DEBUG] Loading Google Maps API")
   console.error("🎯 Fetch error:", error)
   ```

3. **Comprehensive Request Debugging**: For AJAX/fetch requests, log:
   - Form data being sent: `Object.fromEntries(formData)`
   - Request URL and method: `form.action`, `form.method`
   - Response status and headers: `response.status`, `response.headers`
   - Content-Type validation: Check if response is JSON before parsing
   - CSRF token verification: Log token presence and format

4. **Error Context**: Provide detailed error information instead of generic messages
   ```javascript
   .catch(error => {
     console.error("🎯 Fetch error:", error)
     this.showErrorModal([`Network error: ${error.message}`])
   })
   ```

### Debug Mode Usage in Controllers
- Google Maps Service: Enhanced loading detection and duplicate script prevention
- Form Submission Controllers: Full request/response cycle logging
- Onboarding Flow: Location detection and map initialization debugging
- Facebook Integration: OAuth flow and sync status debugging

### Production Safety
- Debug logging automatically disabled when `DEBUG_MODE=off` or not set
- No performance impact in production environments
- Debug messages use clear prefixes for easy filtering

Temporary File Management Rules
1. Always Use /tmp Directory

ALL temporary files MUST be created in the tmp/ directory
Never create temporary files in app/, lib/, config/, or any other project directories
Use Rails.root.join('tmp') to ensure correct path

2. Mandatory Cleanup

Delete temporary files immediately after use
Use ensure blocks to guarantee cleanup even if errors occur
Never leave temporary files behind after task completion

3. Naming Conventions

Use descriptive names with timestamps: tmp/import_#{timestamp}_#{SecureRandom.hex(4)}.csv
Include process identifiers to avoid conflicts: tmp/processing_#{Process.pid}_data.json
Never create numbered duplicates like "filename 2.rb" or "file_copy.rb"


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

Generate Blog pages
  - ✅ data:generate_school_about_pages - Batch generate about pages
  - ✅ data:generate_school_about_page[ID] - Generate for specific school
  - ✅ data:list_schools_for_content_generation - List eligible schools


  4. Admin Interface



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

### Testing Commands
```bash
bundle exec rspec                     # Run all tests
bundle exec rspec spec/models         # Run unit tests only
bundle exec rspec spec/requests       # Run integration tests only
bundle exec rspec spec/system         # Run system tests only
bundle exec rspec --tag js            # Run JavaScript-enabled tests only
HEADLESS=no bundle exec rspec spec/system  # Run system tests with visible browser
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
- **Administrate** gem provides comprehensive admin panel at `/admin/`
- Full CRUD operations for all models with search and filtering capabilities
- **Terms model supports both numeric IDs and slugs** for URL routing (e.g., `/admin/terms/10` or `/admin/terms/thai_national`)
- Available admin interfaces:
  - `/admin/places` - Google Places API data management
  - `/admin/points` - OpenStreetMap points of interest
  - `/admin/schools` - Educational institutions with rich metadata
  - `/admin/media_items` - Photos, videos, documents for places
  - `/admin/events` - Scheduled events and programs
  - `/admin/travel_times` - Transportation data and routes
  - `/admin/school_claims` - Ownership and verification claims
  - `/admin/school_fee_schedules` - Fee structures and pricing
  - `/admin/school_grade_offerings` - Grade levels and curricula
  - `/admin/taggings` - Taxonomy relationships and tagging system
  - `/admin/terms` - Taxonomy terms and categories
  - `/admin/audit_logs` - System activity and change tracking
  - `/admin/vocabularies` - Taxonomy vocabularies and hierarchies
  - `/admin/school_fee_bands` - Fee band structures and tiers

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
- user has to have location in cookie in order for this solution to
  work or else you get redirecte to onboarding. if you use pupeteer
  this wontt work. so if you use pupeteer you have to bypass this
  check and set something like lat lng 3.6923883,100.5171647 as a
  placeholder and value for pupeteer so it dosent get stuck in
  the onboarding

## Styling Guidelines

- Please use normal font black color everywhere on white background unless its a link
- Style it with CSS so we can change it later if needed

## ViewComponent Testing Best Practices

### ❌ **WRONG: Do NOT test `render?` directly**

```ruby
# BAD - This will fail because render? is a private method in ViewComponent
describe '#render?' do
  it 'returns true when data exists' do
    component = MyComponent.new(data: [item])
    expect(component.render?).to be true  # ❌ NoMethodError: private method `render?`
  end
end
```

### ✅ **CORRECT: Test rendering behavior instead**

```ruby
# GOOD - Test the actual rendering behavior
describe 'render behavior' do
  it 'renders when data exists' do
    component = MyComponent.new(data: [item])
    rendered = render_inline(component)
    expect(rendered.to_html.strip).not_to be_empty  # ✅ Tests actual output
  end

  it 'does not render when data is empty' do
    component = MyComponent.new(data: [])
    rendered = render_inline(component)
    expect(rendered.to_html.strip).to be_empty  # ✅ Component returns nothing
  end
end
```

### Why This Approach is Better

1. **Tests Actual Behavior**: Instead of testing internal implementation details (`render?`), we test what the user actually sees
2. **Follows Black Box Testing**: We test inputs and outputs, not internal methods
3. **More Reliable**: Changes to internal ViewComponent implementation won't break our tests
4. **Better Error Messages**: When tests fail, you see exactly what HTML was (or wasn't) rendered

### Testing Private Methods (When Necessary)

If you absolutely need to test private methods for complex logic:

```ruby
# Use send() to access private methods
describe 'private helper methods' do
  let(:component) { MyComponent.new(data: data) }

  it 'processes data correctly' do
    result = component.send(:process_data)
    expect(result).to eq(expected_result)
  end
end
```

## Best Practices and Workflow Notes

- Always continue to fix tests until ALL tests are passing. Don't stop because you completed a task. All tests need to pass for you to be finished.
- Always run Rubocop at the end. It needs to pass before you can consider your task finished
/file:.claude-on-rails/context.md
