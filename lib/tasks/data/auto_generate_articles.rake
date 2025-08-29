# lib/tasks/data/auto_generate_articles.rake
#
# Automatically generates multiple school articles using OpenAI analysis
# Analyzes school data and determines relevant article topics, then generates them
#
# USAGE EXAMPLES:
#
#   # Generate articles for specific school
#   bin/rails data:auto_generate_school_articles[112]
#
#   # Generate specific number of articles
#   ARTICLE_COUNT=7 bin/rails data:auto_generate_school_articles[112]
#
#   # Preview mode - see what articles would be generated
#   DRY_RUN=true bin/rails data:auto_generate_school_articles[112]
#
#   # Force overwrite existing pages
#   OVERWRITE=true bin/rails data:auto_generate_school_articles[112]

require 'json'

namespace :data do
  desc "Auto-generate multiple school articles using OpenAI analysis"
  desc "Usage: rails data:auto_generate_school_articles[SCHOOL_ID]"
  desc "Environment variables:"
  desc "  ARTICLE_COUNT=7 - Number of articles to generate (5-10, default: 6)"
  desc "  DRY_RUN=true - Preview mode, show suggested topics without generating"
  desc "  OVERWRITE=true - Overwrite existing pages instead of skipping them"
  task :auto_generate_school_articles, [:school_id] => :environment do |_task, args|
    
    # Configuration
    school_id = args[:school_id]
    ARTICLE_COUNT = ENV.fetch('ARTICLE_COUNT', 6).to_i.clamp(5, 10)
    DRY_RUN = ENV['DRY_RUN'] == 'true'
    OVERWRITE = ENV['OVERWRITE'] == 'true'
    
    unless school_id.present?
      puts "❌ Error: School ID is required"
      puts "Usage: rails data:auto_generate_school_articles[SCHOOL_ID]"
      puts "Example: rails data:auto_generate_school_articles[112]"
      exit 1
    end
    
    unless ENV['AZURE_OPENAI_API_KEY'].present? && ENV['AZURE_OPENAI_ENDPOINT'].present? && ENV['AZURE_OPENAI_API_DEPLOYMENT'].present?
      puts "❌ Error: Required Azure OpenAI environment variables not set"
      puts "   Required: AZURE_OPENAI_API_KEY, AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_API_DEPLOYMENT"
      exit 1
    end
    
    school = School.find_by(id: school_id)
    unless school
      puts "❌ School with ID #{school_id} not found"
      exit 1
    end
    
    puts "🚀 Auto-generating articles for: #{school.name}"
    puts "📊 Configuration:"
    puts "   📝 Target articles: #{ARTICLE_COUNT}"
    puts "   🧪 Dry run: #{DRY_RUN ? 'Yes' : 'No'}"
    puts "   🔄 Overwrite existing: #{OVERWRITE ? 'Yes' : 'No'}"
    puts ""
    
    begin
      # Step 1: Analyze school data and get article suggestions
      puts "🔍 Analyzing school data to suggest relevant articles..."
      analyzer = SchoolArticleAnalyzer.new(school)
      suggested_articles = analyzer.suggest_articles(ARTICLE_COUNT)
      
      if suggested_articles.empty?
        puts "❌ No article suggestions generated. Check school data completeness."
        exit 1
      end
      
      puts "✅ Generated #{suggested_articles.length} article suggestions:"
      suggested_articles.each_with_index do |article, index|
        puts "   #{index + 1}. #{article[:title]}"
        puts "      #{article[:description]}"
        puts ""
      end
      
      if DRY_RUN
        puts "🧪 DRY RUN MODE - No articles will be generated"
        puts "Run without DRY_RUN=true to generate these articles"
        exit 0
      end
      
      # Step 2: Generate each suggested article
      puts "📝 Generating articles..."
      
      success_count = 0
      skipped_count = 0
      error_count = 0
      
      suggested_articles.each_with_index do |article, index|
        puts "\n#{index + 1}/#{suggested_articles.length} Generating: #{article[:title]}"
        
        begin
          # Check if page already exists
          slug = article[:title].parameterize
          existing_page = school.pages.find_by(slug: slug)
          
          if existing_page && !OVERWRITE
            puts "   ⏭️  Skipped: Page already exists (use OVERWRITE=true to replace)"
            skipped_count += 1
            next
          end
          
          if existing_page && OVERWRITE
            puts "   🔄 Overwriting existing page..."
            existing_page.destroy
          end
          
          # Generate the article using existing service
          generator = SchoolContentGenerator.new(school, article[:title], article[:description])
          page = generator.generate_page
          
          if page
            success_count += 1
            puts "   ✅ Created: #{page.title} (#{page.content.length} characters)"
          else
            error_count += 1
            puts "   ❌ Failed to generate article"
          end
          
          # Rate limiting
          sleep(2) unless index == suggested_articles.length - 1
          
        rescue StandardError => e
          error_count += 1
          puts "   💥 Error: #{e.message}"
          Rails.logger.error "Error generating article '#{article[:title]}' for school #{school_id}: #{e.message}"
        end
      end
      
      # Final summary
      puts "\n🎉 Article generation complete!"
      puts "📊 Summary:"
      puts "   ✅ Successfully generated: #{success_count} articles"
      puts "   ⏭️  Skipped (already exist): #{skipped_count} articles"
      puts "   ❌ Errors: #{error_count} articles"
      puts "   📝 Total pages for #{school.name}: #{school.pages.published.count}"
      
      if success_count > 0
        puts "\n🌐 View generated pages:"
        puts "   Admin: /admin/pages"
        puts "   Public: /schools/#{school.to_param}/pages"
      end
      
    rescue StandardError => e
      puts "❌ Fatal error: #{e.message}"
      Rails.logger.error "Fatal error in auto_generate_school_articles for school #{school_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      exit 1
    end
  end

  desc "Auto-generate articles for ALL schools with dynamic article counts based on data richness"
  desc "Usage: rails data:auto_generate_articles_for_all_schools"
  desc "Environment variables:"
  desc "  FORCE_ARTICLE_COUNT=6 - Force same count for all schools (overrides dynamic calculation)"
  desc "  DRY_RUN=true - Preview mode, show what would be generated"
  desc "  OVERWRITE=true - Overwrite existing pages"
  desc "  BATCH_SIZE=5 - Schools to process per batch (default: 5)"
  desc "  DELAY_BETWEEN_SCHOOLS=10 - Seconds between schools (default: 10)"
  task :auto_generate_articles_for_all_schools => :environment do
    # Configuration
    FORCE_ARTICLE_COUNT = ENV['FORCE_ARTICLE_COUNT']&.to_i&.clamp(3, 10)  # Optional override
    DRY_RUN = ENV['DRY_RUN'] == 'true'
    OVERWRITE = ENV['OVERWRITE'] == 'true'
    BATCH_SIZE = ENV.fetch('BATCH_SIZE', 5).to_i.clamp(1, 20)
    DELAY_BETWEEN_SCHOOLS = ENV.fetch('DELAY_BETWEEN_SCHOOLS', 10).to_i
    
    unless ENV['AZURE_OPENAI_API_KEY'].present? && ENV['AZURE_OPENAI_ENDPOINT'].present? && ENV['AZURE_OPENAI_API_DEPLOYMENT'].present?
      puts "❌ Error: Required Azure OpenAI environment variables not set"
      puts "   Required: AZURE_OPENAI_API_KEY, AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_API_DEPLOYMENT"
      exit 1
    end
    
    # Find schools suitable for article generation
    puts "🔍 Finding schools suitable for article generation..."
    
    # Get all schools with basic data - simplify to avoid complex query issues
    schools_with_data = School.joins(:place)
                             .where.not(places: { name: [nil, ''] })
                             .where.not(schools: { about: [nil, ''] })
                             .includes(:place, :pages, :terms)
                             .order(:id)
    
    puts "📊 School Analysis:"
    puts "   🏫 Total schools in database: #{School.count}"
    puts "   📚 Schools with basic data: #{schools_with_data.count}"
    puts "   ✅ Schools suitable for articles: #{schools_with_data.count}"
    
    if schools_with_data.empty?
      puts "❌ No schools found with sufficient data for article generation"
      exit 1
    end
    
    # Analyze data richness and calculate article counts for preview
    puts "\n📋 Schools to process with dynamic article counts (first 10):"
    total_estimated_articles = 0
    data_richness_distribution = Hash.new(0)
    
    schools_with_data.first(10).each_with_index do |school, index|
      analyzer = SchoolArticleAnalyzer.new(school)
      school_data = analyzer.send(:compile_comprehensive_school_data)
      suggested_count = FORCE_ARTICLE_COUNT || analyzer.send(:calculate_optimal_article_count, school_data)
      existing_pages = school.pages.count
      
      puts "   #{index + 1}. #{school.name} (#{existing_pages} existing, #{suggested_count} planned)"
      total_estimated_articles += suggested_count
      data_richness_distribution[suggested_count] += 1
    end
    
    # Calculate total for all schools
    if schools_with_data.count > 10
      puts "   ... and #{schools_with_data.count - 10} more schools"
      
      # Sample remaining schools to estimate total articles
      sample_size = [schools_with_data.count - 10, 20].min
      remaining_schools = schools_with_data.offset(10).limit(sample_size)
      sample_articles = 0
      
      remaining_schools.each do |school|
        analyzer = SchoolArticleAnalyzer.new(school)
        school_data = analyzer.send(:compile_comprehensive_school_data)
        suggested_count = FORCE_ARTICLE_COUNT || analyzer.send(:calculate_optimal_article_count, school_data)
        sample_articles += suggested_count
        data_richness_distribution[suggested_count] += 1
      end
      
      # Extrapolate for remaining schools
      if schools_with_data.count > 30
        avg_articles = sample_articles.to_f / sample_size
        remaining_count = schools_with_data.count - 30
        total_estimated_articles += sample_articles + (remaining_count * avg_articles).round
      else
        total_estimated_articles += sample_articles
      end
    end
    
    puts "\n📊 Data Richness Analysis:"
    data_richness_distribution.sort.each do |article_count, school_count|
      richness_level = case article_count
                      when 3 then "Minimal"
                      when 4 then "Limited" 
                      when 6 then "Good"
                      when 8 then "Rich"
                      when 10 then "Exceptional"
                      else "Custom"
                      end
      puts "   #{article_count} articles: #{school_count} schools (#{richness_level} data)"
    end
    puts "   📝 Estimated total articles: #{total_estimated_articles}"
    
    if DRY_RUN
      puts "\n🧪 DRY RUN MODE - No articles will be generated"
      puts "Run without DRY_RUN=true to generate articles for all schools"
      exit 0
    end
    
    # Confirm before processing
    puts "\n⚠️  This will generate dynamic article counts for #{schools_with_data.count} schools based on data richness"
    puts "   📝 Estimated total articles: #{total_estimated_articles}"
    puts "   ⏱️  Estimated time: #{((total_estimated_articles * 30) / 60).round} minutes"
    puts "   🎯 Article distribution: 3-10 articles per school based on available data"
    puts "\nThis will use significant Azure OpenAI API credits. Continue? (y/N)"
    
    response = (STDIN.gets || '').chomp.downcase
    unless response == 'y' || response == 'yes'
      puts "❌ Operation cancelled"
      exit 0
    end
    
    # Initialize tracking
    stats = {
      total_schools: schools_with_data.count,
      processed_schools: 0,
      successful_schools: 0,
      failed_schools: 0,
      total_articles_generated: 0,
      start_time: Time.current,
      errors: []
    }
    
    puts "\n🚀 Starting bulk article generation for #{stats[:total_schools]} schools"
    puts "⚙️  Configuration:"
    puts "   📝 Article strategy: #{FORCE_ARTICLE_COUNT ? "Fixed #{FORCE_ARTICLE_COUNT} per school" : 'Dynamic based on data richness (3-10 per school)'}"
    puts "   📦 Batch size: #{BATCH_SIZE} schools"
    puts "   ⏱️  Delay between schools: #{DELAY_BETWEEN_SCHOOLS} seconds"
    puts "   🔄 Overwrite existing: #{OVERWRITE ? 'Yes' : 'No'}"
    
    # Process schools in batches
    total_batches = (schools_with_data.count.to_f / BATCH_SIZE).ceil
    batch_index = 0
    
    schools_with_data.in_batches(of: BATCH_SIZE) do |batch|
      batch_index += 1
      puts "\n📦 Processing batch #{batch_index}/#{total_batches}"
      puts "-" * 80
      
      batch.each do |school|
        stats[:processed_schools] += 1
        
        puts "\n#{stats[:processed_schools]}/#{stats[:total_schools]} Processing: #{school.name}"
        
        begin
          # Generate articles for this school with dynamic count
          analyzer = SchoolArticleAnalyzer.new(school)
          suggested_articles = analyzer.suggest_articles(FORCE_ARTICLE_COUNT)
          
          if suggested_articles.empty?
            puts "   ⚠️  No article suggestions generated - skipping"
            stats[:failed_schools] += 1
            next
          end
          
          article_count_info = FORCE_ARTICLE_COUNT ? "fixed #{FORCE_ARTICLE_COUNT}" : "dynamic #{suggested_articles.length}"
          puts "   📝 Generated #{suggested_articles.length} article suggestions (#{article_count_info})"
          
          school_success_count = 0
          school_error_count = 0
          
          suggested_articles.each_with_index do |article, index|
            begin
              # Check if page already exists
              slug = article[:title].parameterize
              existing_page = school.pages.find_by(slug: slug)
              
              if existing_page && !OVERWRITE
                puts "   #{index + 1}/#{suggested_articles.length} ⏭️  Skipped: #{article[:title]} (exists)"
                next
              end
              
              if existing_page && OVERWRITE
                puts "   #{index + 1}/#{suggested_articles.length} 🔄 Overwriting: #{article[:title]}"
                existing_page.destroy
              end
              
              # Generate the article
              generator = SchoolContentGenerator.new(school, article[:title], article[:description])
              page = generator.generate_page
              
              if page
                school_success_count += 1
                stats[:total_articles_generated] += 1
                puts "   #{index + 1}/#{suggested_articles.length} ✅ Created: #{article[:title]}"
              else
                school_error_count += 1
                puts "   #{index + 1}/#{suggested_articles.length} ❌ Failed: #{article[:title]}"
              end
              
              # Small delay between articles for the same school
              sleep(2) unless index == suggested_articles.length - 1
              
            rescue StandardError => e
              school_error_count += 1
              error_msg = "#{school.name} - #{article[:title]}: #{e.message}"
              stats[:errors] << error_msg
              puts "   #{index + 1}/#{suggested_articles.length} 💥 Error: #{e.message}"
            end
          end
          
          if school_success_count > 0
            stats[:successful_schools] += 1
            puts "   🎉 School complete: #{school_success_count}/#{suggested_articles.length} articles created"
          else
            stats[:failed_schools] += 1
            puts "   ❌ School failed: No articles created"
          end
          
          # Delay between schools
          if stats[:processed_schools] < stats[:total_schools]
            puts "   😴 Sleeping #{DELAY_BETWEEN_SCHOOLS}s before next school..."
            sleep(DELAY_BETWEEN_SCHOOLS)
          end
          
        rescue StandardError => e
          stats[:failed_schools] += 1
          error_msg = "#{school.name} (general error): #{e.message}"
          stats[:errors] << error_msg
          puts "   💥 School processing failed: #{e.message}"
          Rails.logger.error "Error processing school #{school.id}: #{e.message}"
        end
        
        # Progress report every 10 schools
        if stats[:processed_schools] % 10 == 0
          elapsed = Time.current - stats[:start_time]
          rate = stats[:processed_schools] / elapsed * 60  # per minute
          success_rate = (stats[:successful_schools].to_f / stats[:processed_schools] * 100).round(1)
          
          puts "\n📊 Progress Update:"
          puts "   Schools processed: #{stats[:processed_schools]}/#{stats[:total_schools]} (#{success_rate}% success)"
          puts "   Articles created: #{stats[:total_articles_generated]}"
          puts "   Rate: #{rate.round(1)} schools/minute"
          puts "   Elapsed: #{(elapsed / 60).round(1)} minutes"
          
          if stats[:processed_schools] < stats[:total_schools]
            remaining = stats[:total_schools] - stats[:processed_schools]
            eta_minutes = remaining / rate
            puts "   ETA: #{eta_minutes.round(1)} minutes"
          end
        end
      end
      
      # Longer delay between batches
      unless batch_index == total_batches
        batch_delay = DELAY_BETWEEN_SCHOOLS * 2
        puts "\n💤 Batch complete, sleeping #{batch_delay}s before next batch..."
        sleep batch_delay
      end
    end
    
    # Final summary
    total_time = Time.current - stats[:start_time]
    
    puts "\n" + "🎉" * 30
    puts "BULK ARTICLE GENERATION COMPLETE!"
    puts "🎉" * 30
    puts "📊 Final Statistics:"
    puts "   🏫 Schools processed: #{stats[:processed_schools]}"
    puts "   ✅ Successful schools: #{stats[:successful_schools]}"
    puts "   ❌ Failed schools: #{stats[:failed_schools]}"
    puts "   📝 Total articles created: #{stats[:total_articles_generated]}"
    puts "   ⏱️  Total processing time: #{(total_time / 60).round(1)} minutes"
    
    if stats[:processed_schools] > 0
      school_success_rate = (stats[:successful_schools].to_f / stats[:processed_schools] * 100)
      avg_articles_per_school = stats[:total_articles_generated].to_f / stats[:successful_schools]
      puts "   📈 School success rate: #{school_success_rate.round(1)}%"
      puts "   📊 Average articles per successful school: #{avg_articles_per_school.round(1)}"
    end
    
    # Database summary
    total_pages = Page.count
    schools_with_pages = School.joins(:pages).distinct.count
    
    puts "\n📈 Database Status:"
    puts "   📄 Total pages in system: #{total_pages}"
    puts "   🏫 Schools with pages: #{schools_with_pages}"
    puts "   📊 Average pages per school: #{(total_pages.to_f / schools_with_pages).round(1)}"
    
    # Error summary
    if stats[:errors].any?
      puts "\n❌ Error Summary (first 10):"
      stats[:errors].first(10).each do |error|
        puts "   • #{error}"
      end
      
      if stats[:errors].count > 10
        puts "   ... and #{stats[:errors].count - 10} more errors"
      end
    end
    
    puts "\n🌐 View all school pages at: /admin/pages"
    puts "🎉" * 30
  end
end