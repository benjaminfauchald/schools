# Service class for generating AI-powered content for schools using OpenAI
class SchoolContentGenerator
  require 'net/http'
  require 'uri'
  require 'json'

  def initialize(school, title = nil, description = nil)
    @school = school
    @title = title || "About #{school.name}"
    @description = description || "Learn about our school's history, mission, and educational philosophy."
    @api_key = ENV['OPENAI_API_KEY']
  end

  def generate_page
    return unless @api_key.present?
    
    # Check if page already exists for this title
    slug = @title.parameterize
    return if @school.pages.where(slug: slug).exists?

    # Compile school data for AI
    school_data = compile_school_data

    # Generate content using OpenAI
    content = generate_ai_content(school_data, @title, @description)
    
    return unless content.present?

    # Create the page
    page = @school.pages.create!(
      title: @title,
      content: content[:html_content],
      page_type: determine_page_type(@title),
      status: 'published',
      author: 'AI Generated',
      meta_description: content[:meta_description],
      published_at: Time.current,
      sort_order: 0
    )

    Rails.logger.info "Generated '#{@title}' page for school: #{@school.name}"
    page
  end

  # Backwards compatibility
  def generate_about_page
    @title = "About #{@school.name}"
    @description = "Learn about our school's history, mission, and educational philosophy."
    generate_page
  end

  private

  attr_reader :school, :api_key

  def compile_school_data
    {
      # Basic school info
      name: school.name,
      founded_year: school.founded_year,
      ownership: school.ownership,
      about: school.about,
      
      # Location info
      address: school.display_address,
      district: school.district,
      province: school.province,
      
      # Academic info
      grade_offerings: school.school_grade_offering&.grades,
      age_range: "#{school.school_grade_offering&.min_age&.to_i}-#{school.school_grade_offering&.max_age&.to_i}",
      boarding: school.boarding,
      school_bus: school.school_bus,
      language_support: school.language_support_notes,
      
      # Facilities and programs
      curricula: school.curricula.pluck(:label),
      accreditations: school.accreditations.pluck(:label),
      facilities: school.facilities.pluck(:label),
      languages: school.languages.pluck(:label),
      programs: school.programs.pluck(:label),
      extracurriculars: school.extracurriculars.pluck(:label),
      
      # Fee information
      fee_range: school.tuition_range,
      
      # Firecrawl data (primary source)
      website_crawl_data: school.website_crawl_data,
      website_structured_data: school.website_structured_data,
      
      # Contact info
      phone: school.display_phone,
      email: school.email,
      website: school.display_website,
      
      # Social media
      facebook_url: school.facebook_url,
      line_id: school.line_id,
      whatsapp_number: school.whatsapp_number
    }.compact
  end

  def generate_ai_content(school_data, title, description)
    prompt = build_master_prompt(school_data, title, description)
    
    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    
    request.body = {
      model: 'gpt-4',
      messages: [
        {
          role: 'system',
          content: 'You are a professional content writer specializing in educational institution marketing. Write engaging, informative content that highlights the unique aspects of each school.'
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
        
        return parse_ai_response(content_text) if content_text
      else
        Rails.logger.error "OpenAI API error: #{response.code} - #{response.body}"
      end
    rescue StandardError => e
      Rails.logger.error "Error calling OpenAI API: #{e.message}"
    end
    
    nil
  end

  def build_master_prompt(school_data, title, description)
    # Prioritize structured data over raw content
    crawl_data_summary = if school_data[:website_structured_data].present?
      structured_content = format_structured_data(school_data[:website_structured_data])
      "Website structured data: #{structured_content}"
    elsif school_data[:website_crawl_data].present?
      # Fallback to cleaned raw content
      clean_content = extract_meaningful_crawl_content(school_data[:website_crawl_data])
      "Website content: #{clean_content.truncate(5000)}"
    else
      "No website crawl data available"
    end

    prompt = <<~PROMPT
      Create a webpage titled "#{title}" for #{school_data[:name]}, an educational institution.

      Page Description: #{description}

      

      School Information:
      - Name: #{school_data[:name]}
      - Founded: #{school_data[:founded_year] || 'Not specified'}
      - Ownership: #{school_data[:ownership] || 'Not specified'}
      - Location: #{school_data[:address]}
      - District: #{school_data[:district]}
      - Province: #{school_data[:province]}
      - Grade Levels: #{school_data[:grade_offerings] || 'Not specified'}
      - Age Range: #{school_data[:age_range]} years
      - Boarding: #{school_data[:boarding] ? 'Available' : 'Day school only'}
      - Transportation: #{school_data[:school_bus] ? 'School bus available' : 'No school transport'}

      Academic Programs:
      - Curricula: #{school_data[:curricula]&.join(', ') || 'Not specified'}
      - Accreditations: #{school_data[:accreditations]&.join(', ') || 'Not specified'}
      - Languages: #{school_data[:languages]&.join(', ') || 'Not specified'}
      - Programs: #{school_data[:programs]&.join(', ') || 'Not specified'}

      Facilities: #{school_data[:facilities]&.join(', ') || 'Not specified'}
      Extracurriculars: #{school_data[:extracurriculars]&.join(', ') || 'Not specified'}

      Fee Information: #{school_data[:fee_range] || 'Contact school for fees'}

      Contact Information:
      - Phone: #{school_data[:phone] || 'Not specified'}
      - Email: #{school_data[:email] || 'Not specified'}
      - Website: #{school_data[:website] || 'Not specified'}
- Website content: 
      #{crawl_data_summary}

You are an expert content writer specializing in educational institution web content. Generate a well-structured HTML article using modern web design principles taking into account all the data you have on the school above.

CRITICAL FORMATTING REQUIREMENTS:
- Output MUST be valid HTML with Tailwind CSS classes
- Use semantic HTML5 elements
- Apply Tailwind CSS for professional styling
- Follow Flowbite component patterns for enhanced UI

HTML STRUCTURE TEMPLATE:
<article class="max-w-4xl mx-auto px-4 py-8">
  <!-- Hero Section -->
  <header class="mb-12">
    <h1 class="text-4xl md:text-5xl font-bold text-gray-900 mb-4">[Title]</h1>
    <p class="text-xl text-gray-600 leading-relaxed">[Engaging introduction paragraph]</p>
  </header>

  <!-- Main Content Sections -->
  <section class="prose prose-lg max-w-none">
    <h2 class="text-3xl font-semibold text-gray-800 mt-8 mb-4">[Section Title]</h2>
    <p class="text-gray-700 leading-relaxed mb-4">[Content paragraph]</p>
    
    <!-- Use lists where appropriate -->
    <ul class="list-disc list-inside space-y-2 mb-6 text-gray-700">
      <li>[List item]</li>
    </ul>
    
    <!-- Feature Cards (when listing programs/features) -->
    <div class="grid md:grid-cols-2 gap-6 my-8">
      <div class="bg-blue-50 rounded-lg p-6 border border-blue-100">
        <h3 class="text-xl font-semibold text-blue-900 mb-2">[Feature Title]</h3>
        <p class="text-blue-800">[Feature description]</p>
      </div>
    </div>
    
    <!-- Highlight Box for Important Info -->
    <div class="bg-gradient-to-r from-blue-50 to-indigo-50 border-l-4 border-blue-500 p-6 my-8 rounded-r-lg">
      <h3 class="text-lg font-semibold text-blue-900 mb-2">[Highlight Title]</h3>
      <p class="text-blue-800">[Important information]</p>
    </div>
  </section>

  <!-- Call to Action Section -->
  <section class="mt-12 bg-gray-100 rounded-xl p-8 text-center">
    <h2 class="text-2xl font-bold text-gray-900 mb-4">Ready to Learn More?</h2>
    <p class="text-gray-700 mb-6">[CTA text]</p>
    <div class="space-y-2">
      <p class="text-gray-600">Contact us at: <a href="mailto:[email]" class="text-blue-600 hover:text-blue-800 font-medium">[email]</a></p>
      <p class="text-gray-600">Call: <a href="tel:[phone]" class="text-blue-600 hover:text-blue-800 font-medium">[phone]</a></p>
    </div>
  </section>
</article>

CONTENT GUIDELINES:
Title: "#{title}"
Description: #{description}

1. **Opening Section**: Start with an engaging introduction that immediately captures the essence of #{title} at #{school_data[:name]}

2. **Main Content**: Create 3-4 well-structured sections with:
   - Clear H2 headings for major sections (use text-3xl font-semibold)
   - H3 subheadings for subsections (use text-xl font-semibold)
   - Descriptive paragraphs with text-gray-700 for readability
   - Bullet points or numbered lists where appropriate
   - Feature cards for highlighting specific programs or achievements

3. **Visual Hierarchy**:
   - Use varying text sizes to create clear hierarchy
   - Apply proper spacing (mb-4, mb-6, mb-8) between elements
   - Use background colors (bg-blue-50, bg-gray-100) to highlight important sections
   - Include border styling for emphasis (border-l-4 border-blue-500)

4. **Content Requirements**:
   - 400-600 words of engaging, informative content
   - Focus specifically on #{title} aspects of the school
   - Use ONLY factual information from the provided school data
   - Write for prospective students and families
   - Include specific programs, achievements, or unique features

5. **Styling Rules**:
   - Headers: Use Tailwind's typography scale (text-4xl, text-3xl, text-xl)
   - Body text: Use text-gray-700 for primary content, text-gray-600 for secondary
   - Links: Apply text-blue-600 hover:text-blue-800 with font-medium
   - Spacing: Use consistent margin bottom (mb-4, mb-6, mb-8, mb-12)
   - Responsive: Include md: prefixes for larger screens

6. **Special Elements to Include** (where relevant):
   - Statistics or numbers: Display in feature cards with colored backgrounds
   - Key programs: Use grid layout with styled cards
   - Important announcements: Use gradient backgrounds with left border
   - Quotes: Use large text with italic styling and gray background

School Information:
- Name: #{school_data[:name]}
- Location: #{school_data[:address]}
- Academic Programs: #{school_data[:curricula]&.join(', ') || 'Not specified'}
- Facilities: #{school_data[:facilities]&.join(', ') || 'Not specified'}
- Grade Levels: #{school_data[:grade_offerings] || 'Not specified'}

Generate the complete HTML article now, ensuring every element has appropriate Tailwind CSS classes for professional presentation.


      HTML_CONTENT_START
      [Your HTML formatted content here]
      HTML_CONTENT_END

      META_DESCRIPTION_START
      [A 150-160 character SEO meta description for "#{title}" at #{school_data[:name]}]
      META_DESCRIPTION_END
    PROMPT
    puts prompt
    return prompt
  end

  def determine_page_type(title)
    case title.downcase
    when /about/
      'about_us'
    when /swim|pool|aquatic/
      'sports'
    when /horse|equestrian|riding/
      'activities'
    when /academ|curriculum|education/
      'academics'
    when /sport|athletic|team|competition/
      'sports'
    when /activit|club|extracurricular/
      'activities'
    else
      'blog'
    end
  end

  def format_structured_data(structured_data)
    return "" unless structured_data.is_a?(Hash)
    
    formatted_sections = []
    
    # Format each section of structured data
    structured_data.each do |section_key, section_data|
      next unless section_data.is_a?(Hash) && section_data.any?
      
      section_title = section_key.to_s.humanize.titlecase
      formatted_sections << "\n#{section_title}:"
      
      section_data.each do |field_key, field_value|
        next unless field_value.present? && field_value != "N/A"
        
        field_name = field_key.to_s.humanize
        
        if field_value.is_a?(Array)
          formatted_sections << "- #{field_name}: #{field_value.join(', ')}"
        else
          # Limit field value length to avoid overwhelming the prompt
          value = field_value.to_s.truncate(200)
          formatted_sections << "- #{field_name}: #{value}"
        end
      end
    end
    
    formatted_sections.join("\n")
  end

  def extract_meaningful_crawl_content(crawl_data)
    return "" unless crawl_data.is_a?(Array) && crawl_data.any?
    
    # Extract and clean markdown content from all pages
    meaningful_content = crawl_data.map do |page|
      next "" unless page.is_a?(Hash) && page["markdown"].present?
      
      markdown = page["markdown"]
      
      # Remove analytics blocking and noise patterns - be more aggressive
      cleaned = markdown.dup
      
      # Remove analytics blocking sections
      cleaned.gsub!(/app\.visitor-analytics\.io.*?ERR\\?_BLOCKED\\?_BY\\?_CLIENT.*?Reload\n*/m, "")
      cleaned.gsub!(/loadbalancer\.visitor-analytics\.io.*?ERR\\?_BLOCKED\\?_BY\\?_CLIENT.*?Reload\n*/m, "")
      cleaned.gsub!(/This page has been blocked by an extension.*?Reload\n*/m, "")
      
      # Remove page structure noise
      cleaned.gsub!(/^top of page\s*\n*Skip to Main Content\s*\n*/m, "")
      cleaned.gsub!(/^bottom of page.*$/m, "")
      
      # Remove cookie/privacy notices
      cleaned.gsub!(/We use cookies.*?Accept\s*\n*/m, "")
      cleaned.gsub!(/Privacy Policy.*?\n*/m, "")
      cleaned.gsub!(/Settings.*?Accept.*?Close\s*\n*/m, "")
      
      # Remove base64 image placeholders
      cleaned.gsub!(/!\[\].*?<Base64-Image-Removed>.*?\)/m, "")
      
      # Clean up extra whitespace
      cleaned.gsub!(/\n{3,}/, "\n\n")
      cleaned.gsub!(/\s+\n/, "\n")
      cleaned.strip!
      
      # Only keep pages with substantial educational content
      has_educational_content = cleaned.match?(/school|education|student|academic|curriculum|program|class|learn|teach|grade/i)
      
      if has_educational_content && cleaned.length > 200
        cleaned
      else
        ""
      end
    end.reject(&:empty?).join("\n\n")
    
    # Return the cleaned, meaningful content
    meaningful_content.strip
  end

  def parse_ai_response(content)
    html_match = content.match(/HTML_CONTENT_START\s*(.*?)\s*HTML_CONTENT_END/m)
    meta_match = content.match(/META_DESCRIPTION_START\s*(.*?)\s*META_DESCRIPTION_END/m)
    
    return nil unless html_match

    {
      html_content: html_match[1].strip,
      meta_description: meta_match&.[](1)&.strip
    }
  end
end