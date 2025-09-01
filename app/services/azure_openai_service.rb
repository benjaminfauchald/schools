class AzureOpenaiService
  include HTTParty
  
  def initialize
    @api_key = azure_openai_api_key
    @endpoint = azure_openai_endpoint
    @deployment_name = azure_openai_deployment
    @api_version = '2024-02-15-preview'
    
    validate_configuration!
  end
  
  def generate_blog_post(place, topic, context_data, options = {})
    word_count = options[:word_count] || 800
    tone = options[:tone] || 'informative'
    audience = options[:audience] || 'parents and students'
    
    Rails.logger.info "Generating blog post for place #{place.id}, topic: '#{topic}'"
    Rails.logger.info "Context tokens: #{context_data[:token_count]}, word count: #{word_count}"
    
    system_prompt = build_system_prompt(place, tone, audience)
    user_prompt = build_user_prompt(topic, word_count, context_data)
    
    response = make_chat_request(system_prompt, user_prompt, options)
    
    handle_response(response)
  rescue => e
    Rails.logger.error "Azure OpenAI Service Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    {
      success: false,
      error: "Blog generation failed: #{e.message}",
      error_type: e.class.name
    }
  end
  
  def test_connection
    response = make_chat_request(
      "You are a helpful assistant.",
      "Say 'Hello, Azure OpenAI is working!' in exactly those words.",
      { max_tokens: 50, temperature: 0 }
    )
    
    handle_response(response)
  end
  
  private
  
  def make_chat_request(system_prompt, user_prompt, options = {})
    url = "#{@endpoint}/openai/deployments/#{@deployment_name}/chat/completions"
    
    body = {
      messages: [
        { role: 'system', content: system_prompt },
        { role: 'user', content: user_prompt }
      ],
      max_tokens: options[:max_tokens] || 2000,
      temperature: options[:temperature] || 0.7,
      top_p: options[:top_p] || 0.9,
      frequency_penalty: options[:frequency_penalty] || 0.1,
      presence_penalty: options[:presence_penalty] || 0.1,
      stream: false
    }
    
    Rails.logger.info "Making Azure OpenAI request to: #{url}"
    Rails.logger.info "Request token estimate: #{EmbeddingService.estimate_tokens(system_prompt + user_prompt)}"
    
    self.class.post(
      url,
      headers: {
        'Content-Type' => 'application/json',
        'api-key' => @api_key
      },
      query: { 'api-version' => @api_version },
      body: body.to_json,
      timeout: 120 # 2 minutes timeout
    )
  end
  
  def build_system_prompt(place, tone, audience)
    place_info = build_place_context(place)
    
    <<~PROMPT
      You are an expert content writer creating engaging blog posts for #{place.name}.
      
      #{place_info}
      
      Writing Guidelines:
      - Tone: #{tone} - write in a #{tone} style that resonates with the audience
      - Target Audience: #{audience} - tailor your language and examples for this specific audience
      - Write in clear, engaging, and accessible language
      - Use the provided context as your PRIMARY and ONLY source of information
      - Only include information that can be directly supported by the context provided
      - Include specific examples, quotes, and details from the context when relevant
      - Structure with clear headings and well-organized paragraphs
      - Make the content actionable and valuable for readers
      - End with a compelling call-to-action that encourages engagement with #{place.name}
      
      CRITICAL REQUIREMENTS:
      - Base ALL content exclusively on the provided context
      - Do not add information not present in the context
      - If the context doesn't provide enough information for a comprehensive blog post, focus on what is available and indicate areas where more information would be valuable
      - Cite specific sources when referencing video transcripts or documents
      - Maintain factual accuracy and avoid speculation
      
      Content Structure Requirements:
      1. Compelling headline that captures the topic and appeals to the target audience
      2. Engaging introduction that hooks the reader and previews what they'll learn
      3. Well-organized main content with 3-4 clear sections using descriptive subheadings
      4. Specific examples, quotes, or anecdotes from the provided context
      5. Practical takeaways or actionable insights for readers
      6. Strong conclusion that summarizes key points and includes a relevant call-to-action
    PROMPT
  end
  
  def build_place_context(place)
    context_parts = []
    
    context_parts << "Place Information:"
    context_parts << "- Name: #{place.name}"
    context_parts << "- Type: #{place.primary_type&.humanize || 'Educational Institution'}"
    context_parts << "- Location: #{place.formatted_address}" if place.formatted_address.present?
    context_parts << "- Rating: #{place.rating} stars (#{place.user_ratings_total} reviews)" if place.rating.present?
    
    # Add business hours if available
    if place.opening_hours.present? && place.opening_hours['weekday_text'].present?
      context_parts << "- Hours: #{place.opening_hours['weekday_text'].first}" 
    end
    
    # Add contact information
    contact_info = []
    contact_info << "Phone: #{place.phone_display}" if place.phone_display.present?
    contact_info << "Website: #{place.website}" if place.website.present?
    
    if contact_info.any?
      context_parts << "- Contact: #{contact_info.join(', ')}"
    end
    
    context_parts.join("\n")
  end
  
  def build_user_prompt(topic, word_count, context_data)
    prompt_parts = []
    
    prompt_parts << "BLOG POST REQUEST:"
    prompt_parts << "Topic: #{topic}"
    prompt_parts << "Target Length: #{word_count} words"
    prompt_parts << "Sources Available: #{context_data[:sources_used]} sources with #{context_data[:token_count]} tokens of content"
    prompt_parts << ""
    
    if context_data[:context].present?
      prompt_parts << "CONTEXT INFORMATION:"
      prompt_parts << context_data[:context]
      prompt_parts << ""
    else
      prompt_parts << "⚠️ LIMITED CONTEXT: No specific content was found for this topic. Please create a general blog post about '#{topic}' while acknowledging the limited information available."
      prompt_parts << ""
    end
    
    prompt_parts << "TASK:"
    prompt_parts << "Write a comprehensive, engaging blog post on '#{topic}' using ONLY the context information provided above."
    prompt_parts << ""
    prompt_parts << "Requirements:"
    prompt_parts << "- Use the exact structure specified in the system prompt"
    prompt_parts << "- Reference specific sources when mentioning information (e.g., 'As mentioned in the video about...', 'According to the document on...')"
    prompt_parts << "- Include relevant quotes or specific details from transcripts and documents"
    prompt_parts << "- Ensure all claims are supported by the provided context"
    prompt_parts << "- Write approximately #{word_count} words"
    prompt_parts << "- Make it valuable and actionable for the target audience"
    
    prompt_parts.join("\n")
  end
  
  def handle_response(response)
    if response.success?
      content = response.dig('choices', 0, 'message', 'content')
      
      if content.present?
        Rails.logger.info "Successfully generated blog content (#{content.length} characters)"
        
        {
          success: true,
          content: content,
          usage: response['usage'] || {},
          model: response['model'],
          finish_reason: response.dig('choices', 0, 'finish_reason')
        }
      else
        Rails.logger.error "Empty content in successful response"
        Rails.logger.error "Full response: #{response.body}"
        
        {
          success: false,
          error: 'Empty content returned from Azure OpenAI',
          response_body: response.body
        }
      end
    else
      error_message = response.dig('error', 'message') || 'Unknown error occurred'
      error_code = response.dig('error', 'code') || response.code
      
      Rails.logger.error "Azure OpenAI API Error: #{error_code} - #{error_message}"
      Rails.logger.error "Full response: #{response.body}"
      
      {
        success: false,
        error: error_message,
        error_code: error_code,
        status: response.code,
        response_body: response.body
      }
    end
  end
  
  def validate_configuration!
    missing_configs = []
    missing_configs << 'AZURE_OPENAI_API_KEY' if @api_key.blank?
    missing_configs << 'AZURE_OPENAI_ENDPOINT' if @endpoint.blank?
    missing_configs << 'AZURE_OPENAI_DEPLOYMENT' if @deployment_name.blank?
    
    if missing_configs.any?
      raise ArgumentError, "Missing Azure OpenAI configuration: #{missing_configs.join(', ')}"
    end
    
    unless @endpoint.start_with?('https://')
      raise ArgumentError, "Azure OpenAI endpoint must be a valid HTTPS URL"
    end
  end
  
  def azure_openai_api_key
    ENV['AZURE_OPENAI_API_KEY']
  end
  
  def azure_openai_endpoint
    ENV['AZURE_OPENAI_ENDPOINT']
  end
  
  def azure_openai_deployment
    ENV['AZURE_OPENAI_API_DEPLOYMENT'] || ENV['AZURE_OPENAI_DEPLOYMENT']
  end
end