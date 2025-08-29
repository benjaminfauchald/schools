# Service class for analyzing school data and suggesting relevant article topics using Azure OpenAI
class SchoolArticleAnalyzer
  require 'net/http'
  require 'uri'
  require 'json'

  def initialize(school)
    @school = school
    @api_key = ENV['AZURE_OPENAI_API_KEY']
    @endpoint = ENV['AZURE_OPENAI_ENDPOINT']
    @deployment = ENV['AZURE_OPENAI_API_DEPLOYMENT']
  end

  def suggest_articles(count = nil)
    return [] unless @api_key.present? && @endpoint.present? && @deployment.present?
    
    # Compile comprehensive school data
    school_data = compile_comprehensive_school_data
    
    # Calculate optimal article count based on data richness if not specified
    optimal_count = count || calculate_optimal_article_count(school_data)
    
    # Generate article suggestions using OpenAI
    suggestions = generate_article_suggestions(school_data, optimal_count)
    
    return suggestions if suggestions.present?
    
    # Fallback suggestions if OpenAI fails
    generate_fallback_suggestions(optimal_count)
  end

  private

  attr_reader :school, :api_key, :endpoint, :deployment

  def calculate_optimal_article_count(school_data)
    # Score the richness of school data across different categories
    score = 0
    
    # Basic information score (max: 2 points)
    score += 1 if school_data[:about].present? && school_data[:about].length > 50
    score += 1 if school_data[:founded_year].present?
    
    # Academic programs score (max: 3 points)
    curricula_count = school_data[:curricula]&.length || 0
    score += [curricula_count, 2].min  # Up to 2 points for curricula variety
    score += 1 if school_data[:accreditations]&.any?
    
    # Facilities and programs score (max: 3 points)
    facilities_count = school_data[:facilities]&.length || 0
    score += 1 if facilities_count >= 3
    score += 1 if facilities_count >= 6
    score += 1 if school_data[:programs]&.any?
    
    # Activities and enrichment score (max: 2 points)
    extracurricular_count = school_data[:extracurriculars]&.length || 0
    score += 1 if extracurricular_count >= 2
    score += 1 if extracurricular_count >= 5
    
    # Website and detailed info score (max: 2 points)
    score += 1 if school_data[:website_structured_data].present?
    score += 1 if school_data[:languages]&.length&.>= 2
    
    # Additional features score (max: 3 points)
    score += 1 if school_data[:boarding]
    score += 1 if school_data[:school_bus]
    score += 1 if school_data[:fee_range].present?
    
    # Convert score to article count (3-10 articles based on data richness)
    case score
    when 0..2
      3  # Minimal data - basic articles only
    when 3..5
      4  # Limited data - core topics
    when 6..8
      6  # Good data - comprehensive coverage
    when 9..12
      8  # Rich data - extensive articles
    else
      10 # Exceptional data - maximum articles
    end
  end

  def compile_comprehensive_school_data
    {
      # Basic school info
      name: school.name,
      founded_year: school.founded_year,
      ownership: school.ownership,
      about: school.about,
      
      # Location and basic details
      address: school.display_address,
      district: school.district,
      province: school.province,
      
      # Academic information
      grade_offerings: school.school_grade_offering&.grades,
      age_range: school.age_range,
      educational_level: school.educational_level,
      boarding: school.boarding,
      school_bus: school.school_bus,
      language_support: school.language_support_notes,
      
      # Programs and curricula
      curricula: school.curricula.pluck(:label),
      accreditations: school.accreditations.pluck(:label),
      languages: school.languages.pluck(:label),
      programs: school.programs.pluck(:label),
      
      # Facilities and amenities
      facilities: school.facilities.pluck(:label),
      
      # Activities and enrichment
      extracurriculars: school.extracurriculars.pluck(:label),
      
      # Financial information
      fee_range: school.tuition_range,
      
      # Website crawl data (if available)
      website_structured_data: school.website_structured_data,
      
      # Contact and social
      phone: school.display_phone,
      email: school.email,
      website: school.display_website,
      facebook_url: school.facebook_url,
      line_id: school.line_id,
      whatsapp_number: school.whatsapp_number,
      
      # Pages already created (to avoid duplicates)
      existing_pages: school.pages.pluck(:title, :page_type)
    }.compact
  end

  def generate_article_suggestions(school_data, count)
    prompt = build_article_analysis_prompt(school_data, count)
    
    # Build Azure OpenAI endpoint URL
    azure_url = "#{endpoint}/openai/deployments/#{deployment}/chat/completions?api-version=2024-02-15-preview"
    uri = URI(azure_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['api-key'] = api_key  # Azure uses 'api-key' header instead of 'Authorization'
    request['Content-Type'] = 'application/json'
    
    request.body = {
      messages: [
        {
          role: 'system',
          content: 'You are an expert educational content strategist who analyzes school data to suggest relevant, engaging article topics that will appeal to prospective students and parents.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      max_tokens: 2000,
      temperature: 0.7
    }.to_json

    begin
      response = http.request(request)
      
      if response.code == '200'
        result = JSON.parse(response.body)
        content_text = result.dig('choices', 0, 'message', 'content')
        
        return parse_article_suggestions(content_text) if content_text
      else
        Rails.logger.error "Azure OpenAI API error: #{response.code} - #{response.body}"
      end
    rescue StandardError => e
      Rails.logger.error "Error calling Azure OpenAI API for article suggestions: #{e.message}"
    end
    
    []
  end

  def build_article_analysis_prompt(school_data, count)
    # Extract key features for analysis
    key_features = extract_key_features(school_data)
    
    prompt = <<~PROMPT
      Analyze this school's information and suggest #{count} relevant, engaging article topics that would be valuable for prospective students and families.

      SCHOOL INFORMATION:
      Name: #{school_data[:name]}
      Location: #{school_data[:address]}
      Grade Levels: #{school_data[:grade_offerings] || 'Not specified'}
      Age Range: #{school_data[:age_range]}
      Educational Level: #{school_data[:educational_level]}
      Boarding: #{school_data[:boarding] ? 'Available' : 'Day school only'}
      Transportation: #{school_data[:school_bus] ? 'School bus available' : 'No school transport'}

      ACADEMIC PROGRAMS:
      Curricula: #{school_data[:curricula]&.join(', ') || 'Not specified'}
      Accreditations: #{school_data[:accreditations]&.join(', ') || 'Not specified'}
      Languages: #{school_data[:languages]&.join(', ') || 'Not specified'}
      Programs: #{school_data[:programs]&.join(', ') || 'Not specified'}

      FACILITIES: #{school_data[:facilities]&.join(', ') || 'Not specified'}
      
      EXTRACURRICULARS: #{school_data[:extracurriculars]&.join(', ') || 'Not specified'}

      FEE INFORMATION: #{school_data[:fee_range] || 'Contact school for fees'}

      #{format_website_data(school_data[:website_structured_data])}

      EXISTING PAGES (avoid duplicating these topics):
      #{school_data[:existing_pages]&.map { |title, type| "- #{title} (#{type})" }&.join("\n") || 'None'}

      INSTRUCTIONS:
      1. Suggest #{count} article topics that are:
         - Directly relevant to this specific school's strengths and offerings
         - Appealing to prospective students and parents
         - Based on actual school data provided above
         - Different from existing pages listed above
         
      2. Focus on topics that highlight:
         - Unique programs or facilities this school offers
         - Academic strengths and achievements
         - Student life and community aspects
         - Special features that set this school apart
         
      3. Avoid generic topics - make them specific to this school's actual offerings

      4. Return EXACTLY #{count} suggestions in this format:

      ARTICLE_SUGGESTIONS_START
      1. Title: [Specific, engaging title]
         Description: [Brief description explaining what the article would cover]

      2. Title: [Specific, engaging title]
         Description: [Brief description explaining what the article would cover]

      [Continue for all #{count} suggestions...]
      ARTICLE_SUGGESTIONS_END

      Generate #{count} specific, relevant article topics now:
    PROMPT

    prompt
  end

  def extract_key_features(school_data)
    features = []
    
    # Add curricula as key features
    if school_data[:curricula]&.any?
      features.concat(school_data[:curricula])
    end
    
    # Add notable facilities
    if school_data[:facilities]&.any?
      notable_facilities = school_data[:facilities].select do |facility|
        facility.match?(/pool|lab|theatre|library|sports|maker|innovation/i)
      end
      features.concat(notable_facilities)
    end
    
    # Add special programs
    if school_data[:programs]&.any?
      features.concat(school_data[:programs])
    end
    
    # Add extracurriculars
    if school_data[:extracurriculars]&.any?
      features.concat(school_data[:extracurriculars].first(3)) # Limit to avoid overwhelming
    end
    
    features
  end

  def format_website_data(website_data)
    return "" unless website_data.is_a?(Hash)
    
    formatted = "ADDITIONAL WEBSITE INFORMATION:\n"
    
    website_data.each do |section_key, section_data|
      next unless section_data.is_a?(Hash) && section_data.any?
      
      formatted += "#{section_key.to_s.humanize}:\n"
      section_data.each do |key, value|
        next unless value.present? && value != "N/A"
        
        if value.is_a?(Array)
          formatted += "- #{key.humanize}: #{value.join(', ')}\n"
        else
          formatted += "- #{key.humanize}: #{value.to_s.truncate(100)}\n"
        end
      end
      formatted += "\n"
    end
    
    formatted
  end

  def parse_article_suggestions(content)
    suggestions = []
    
    # Extract content between markers
    match = content.match(/ARTICLE_SUGGESTIONS_START\s*(.*?)\s*ARTICLE_SUGGESTIONS_END/m)
    return suggestions unless match
    
    suggestions_text = match[1]
    
    # Parse each numbered suggestion
    suggestions_text.scan(/(\d+)\.\s*Title:\s*(.+?)\s*Description:\s*(.+?)(?=\d+\.\s*Title:|\z)/m) do |number, title, description|
      suggestions << {
        title: title.strip,
        description: description.strip.gsub(/\n\s*/, ' ')
      }
    end
    
    suggestions
  end

  def generate_fallback_suggestions(count)
    # Fallback suggestions based on school data
    suggestions = []
    
    # Analyze school data to create contextual fallbacks
    if school.curricula.any?
      curriculum_name = school.curricula.first.label
      suggestions << {
        title: "Excellence in #{curriculum_name}",
        description: "Discover how #{school.name} delivers outstanding #{curriculum_name} education"
      }
    end
    
    if school.facilities.any?
      facility = school.facilities.first.label
      suggestions << {
        title: "State-of-the-Art #{facility}",
        description: "Explore our modern #{facility.downcase} and learning environment"
      }
    end
    
    if school.extracurriculars.any?
      activity = school.extracurriculars.first.label
      suggestions << {
        title: "Beyond the Classroom: #{activity}",
        description: "How #{activity.downcase} enriches student life at #{school.name}"
      }
    end
    
    # Add generic but useful suggestions
    suggestions << {
      title: "A Day in the Life at #{school.name}",
      description: "Follow a typical student through their daily journey at our school"
    }
    
    suggestions << {
      title: "Our Teaching Philosophy",
      description: "Understanding the educational approach that makes #{school.name} unique"
    }
    
    suggestions << {
      title: "Community and Culture",
      description: "The vibrant school community that welcomes students from diverse backgrounds"
    }
    
    # Return requested count
    suggestions.first(count)
  end
end