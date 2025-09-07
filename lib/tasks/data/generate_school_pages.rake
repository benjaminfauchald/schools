namespace :data do
  desc "Generate dynamic AI-powered page for specific school with title and description"
  task :generate_school_page, [ :school_id, :title, :description ] => :environment do |_task, args|
    school_id = args[:school_id]
    title = args[:title] || "About Us"
    description = args[:description] || "Learn about our school"

    unless school_id.present?
      puts "Usage: rails data:generate_school_page[SCHOOL_ID,TITLE,DESCRIPTION]"
      puts "Example: rails data:generate_school_page[112,\"Swimming Program\",\"Our comprehensive swimming facilities and training programs\"]"
      puts "Example: rails data:generate_school_page[112,\"About Us\",\"Learn about our school's mission and values\"]"
      exit 1
    end

    unless ENV["OPENAI_API_KEY"].present?
      puts "❌ Error: OPENAI_API_KEY environment variable not set"
      exit 1
    end

    school = School.find_by(id: school_id)
    unless school
      puts "❌ School with ID #{school_id} not found"
      exit 1
    end

    # Check if page already exists for this title - auto-overwrite
    slug = title.parameterize
    if school.pages.where(slug: slug).exists?
      existing_page = school.pages.where(slug: slug).first
      puts "⚠️  Found existing page: '#{existing_page.title}' (#{existing_page.page_type})"
      puts "   🔄 Overwriting with new content..."

      # Delete existing page to create new one
      existing_page.destroy
    end

    puts "🚀 Generating '#{title}' page for: #{school.name}"
    puts "   Description: #{description}"

    begin
      generator = SchoolContentGenerator.new(school, title, description)
      page = generator.generate_page

      if page
        puts "✅ Page created successfully!"
        puts "   Title: #{page.title}"
        puts "   Slug: #{page.slug}"
        puts "   Type: #{page.page_type}"
        puts "   Status: #{page.status}"
        puts "   URL: /schools/#{school.to_param}/pages/#{page.to_param}"
        puts "   Content length: #{page.content.length} characters"
      else
        puts "❌ Failed to create page"
      end

    rescue StandardError => e
      puts "❌ Error: #{e.message}"
      Rails.logger.error "Error generating content for school #{school_id}, title '#{title}': #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  desc "Generate AI-powered About Us pages for schools with crawl data"
  task generate_school_about_pages: :environment do
    puts "🚀 Starting AI content generation for school About pages..."

    # Check for API key
    unless ENV["OPENAI_API_KEY"].present?
      puts "❌ Error: OPENAI_API_KEY environment variable not set"
      exit 1
    end

    # Find schools with crawl data that don't have about pages
    schools = School.where.not(website_crawl_data: nil)
                   .left_joins(:pages)
                   .where(pages: { page_type: [ "about_us", nil ] })
                   .group("schools.id")
                   .having("COUNT(CASE WHEN pages.page_type = ? THEN 1 END) = 0", "about_us")
                   .limit(10) # Process in batches

    if schools.empty?
      puts "✅ No schools found that need About pages generated"
      exit 0
    end

    school_count = schools.length
    puts "📝 Found #{school_count} schools to process"

    success_count = 0
    error_count = 0

    schools.find_each.with_index do |school, index|
      puts "\n#{index + 1}/#{school_count} Processing: #{school.name}"

      begin
        generator = SchoolContentGenerator.new(school, "About #{school.name}", "Learn about our school's history, mission, and educational philosophy.")
        generator.generate_page

        # Check if page was created
        if school.pages.about_us.exists?
          success_count += 1
          puts "  ✅ About page created successfully"
        else
          error_count += 1
          puts "  ❌ Failed to create About page"
        end

        # Rate limiting to be respectful to OpenAI API
        sleep(2) unless index == school_count - 1

      rescue StandardError => e
        error_count += 1
        puts "  ❌ Error: #{e.message}"
        Rails.logger.error "Error generating content for school #{school.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    puts "\n🎉 Generation complete!"
    puts "✅ Successfully generated: #{success_count} pages"
    puts "❌ Errors: #{error_count} pages"

    if success_count > 0
      puts "\n📄 Generated pages can be viewed in the admin interface:"
      puts "   /admin/pages"
    end
  end

  desc "Generate About page for a specific school by ID"
  task :generate_school_about_page, [ :school_id ] => :environment do |_task, args|
    school_id = args[:school_id]

    unless school_id.present?
      puts "Usage: rails data:generate_school_about_page[SCHOOL_ID]"
      exit 1
    end

    unless ENV["OPENAI_API_KEY"].present?
      puts "❌ Error: OPENAI_API_KEY environment variable not set"
      exit 1
    end

    school = School.find_by(id: school_id)
    unless school
      puts "❌ School with ID #{school_id} not found"
      exit 1
    end

    if school.pages.about_us.exists?
      puts "⚠️  School already has an About page"
      puts "   Existing page: '#{school.pages.about_us.first.title}'"
      print "   Continue anyway? (y/N): "

      response = STDIN.gets.chomp.downcase
      unless response == "y" || response == "yes"
        puts "Operation cancelled"
        exit 0
      end
    end

    puts "🚀 Generating About page for: #{school.name}"

    begin
      generator = SchoolContentGenerator.new(school, "About #{school.name}", "Learn about our school's history, mission, and educational philosophy.")
      generator.generate_page

      if school.pages.about_us.exists?
        about_page = school.pages.about_us.first
        puts "✅ About page created successfully!"
        puts "   Title: #{about_page.title}"
        puts "   Status: #{about_page.status}"
        puts "   Content length: #{about_page.content.length} characters"
      else
        puts "❌ Failed to create About page"
      end

    rescue StandardError => e
      puts "❌ Error: #{e.message}"
      Rails.logger.error "Error generating content for school #{school_id}: #{e.message}"
    end
  end

  desc "List schools eligible for About page generation"
  task list_schools_for_content_generation: :environment do
    puts "🔍 Schools eligible for AI content generation:\n"

    schools = School.where.not(website_crawl_data: nil)
                   .left_joins(:pages)
                   .where(pages: { page_type: [ "about_us", nil ] })
                   .group("schools.id")
                   .having("COUNT(CASE WHEN pages.page_type = ? THEN 1 END) = 0", "about_us")
                   .includes(:pages)

    if schools.empty?
      puts "✅ No schools found that need About pages"
      puts "   All schools with crawl data already have About pages"
      return
    end

    schools.find_each.with_index do |school, index|
      crawl_data_size = school.website_crawl_data&.to_s&.length || 0

      puts "#{index + 1}. #{school.name} (ID: #{school.id})"
      puts "   District: #{school.district}"
      puts "   Crawl data size: #{number_with_delimiter(crawl_data_size)} characters"
      puts "   Last crawled: #{school.website_crawled_at&.strftime('%Y-%m-%d %H:%M') || 'Unknown'}"
      puts ""
    end

    puts "Total eligible schools: #{schools.length}"
  end

  private

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
