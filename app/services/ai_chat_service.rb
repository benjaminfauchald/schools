# AI Chat Service for handling Azure OpenAI API integration
# Provides RAG-powered chat responses using school-specific data
class AiChatService
  include HTTParty

  def initialize(conversation)
    @conversation = conversation
    @school = conversation.school
    @user = conversation.user
    @content_retrieval = ContentRetrievalService.new(@school)
  end

  # Generate AI response for a user message
  def generate_response(user_message, options = {})
    Rails.logger.info "🤖 AiChatService.generate_response started"
    Rails.logger.info "🏫 School: #{@school.name} (ID: #{@school.id})"
    Rails.logger.info "💬 Conversation: #{@conversation.id}"
    Rails.logger.info "📝 Message: #{user_message.truncate(100)}"

    begin
      Rails.logger.info "📨 Adding user message to conversation..."
      # Add user message to conversation
      user_msg = @conversation.add_user_message(user_message)
      Rails.logger.info "✅ User message added with ID: #{user_msg.id}"

      Rails.logger.info "🔍 Retrieving context using RAG..."
      # Retrieve relevant context using RAG
      context_data = @content_retrieval.retrieve_context(user_message, options)
      Rails.logger.info "📊 Context retrieved: #{context_data[:items_used]} items from #{context_data[:data_sources].keys.join(', ')}"

      Rails.logger.info "☁️ Calling Azure OpenAI API..."
      # Generate AI response
      response_data = call_ai_api(user_message, context_data)
      Rails.logger.info "✅ Azure OpenAI response received - Tokens: #{response_data[:tokens_used]}, Time: #{response_data[:processing_time]}s"

      Rails.logger.info "💾 Adding assistant message to conversation..."
      # Add assistant response to conversation
      assistant_msg = @conversation.add_assistant_message(
        response_data[:content],
        context_data[:source_references],
        {
          model: response_data[:model],
          tokens_used: response_data[:tokens_used],
          processing_time: response_data[:processing_time],
          context_items_used: context_data[:items_used]
        }
      )
      Rails.logger.info "✅ Assistant message added with ID: #{assistant_msg.id}"

      {
        success: true,
        user_message: user_msg,
        assistant_message: assistant_msg,
        context_data: context_data,
        metadata: response_data
      }

    rescue => e
      Rails.logger.error "💥 EXCEPTION in AiChatService.generate_response:"
      Rails.logger.error "   Error Class: #{e.class.name}"
      Rails.logger.error "   Error Message: #{e.message}"
      Rails.logger.error "   Backtrace (first 10 lines):"
      e.backtrace.first(10).each { |line| Rails.logger.error "     #{line}" }

      # Determine appropriate error message
      error_message = if e.message.include?("AZURE_OPENAI")
        "AI chat is currently not configured. Please contact support for assistance."
      else
        "I'm sorry, I'm having trouble processing your request right now. Please try again in a moment."
      end

      Rails.logger.info "📝 Adding error message to conversation..."
      # Add error message to conversation
      error_msg = @conversation.add_assistant_message(
        error_message,
        [],
        { error: e.message, timestamp: Time.current.iso8601 }
      )

      {
        success: false,
        error: e.message,
        assistant_message: error_msg
      }
    end
  end

  # Generate suggested questions based on school data
  def generate_suggested_questions(limit: 5)
    begin
      # Get school data summary
      school_summary = @content_retrieval.generate_school_summary

      # Generate contextual questions
      questions = generate_contextual_questions(school_summary, limit)

      # Add suggested questions to conversation
      questions.each do |question|
        @conversation.add_suggested_question(question[:text], question[:metadata])
      end

      {
        success: true,
        questions: questions,
        school_summary: school_summary
      }

    rescue => e
      Rails.logger.error "Suggested Questions Error: #{e.message}"

      # Fallback to default questions
      default_questions = get_default_questions

      {
        success: false,
        error: e.message,
        questions: default_questions
      }
    end
  end

  # Analyze school data completeness and suggest improvements
  def analyze_data_gaps
    begin
      gap_analysis = @content_retrieval.analyze_data_completeness

      # Generate improvement suggestions
      suggestions = generate_improvement_suggestions(gap_analysis)

      # Create data analysis message
      content = format_gap_analysis_response(gap_analysis, suggestions)

      analysis_msg = @conversation.add_data_analysis(
        content,
        gap_analysis[:source_references],
        {
          completeness_score: gap_analysis[:completeness_score],
          missing_fields: gap_analysis[:missing_fields],
          suggestions_count: suggestions.length
        }
      )

      {
        success: true,
        analysis: gap_analysis,
        suggestions: suggestions,
        message: analysis_msg
      }

    rescue => e
      Rails.logger.error "Data Gap Analysis Error: #{e.message}"

      {
        success: false,
        error: e.message
      }
    end
  end

  private

  def call_ai_api(user_message, context_data)
    Rails.logger.info "☁️ call_ai_api started"

    # Validate Azure OpenAI configuration before API call
    Rails.logger.info "🔧 Validating Azure OpenAI configuration..."
    validate_azure_config
    Rails.logger.info "✅ Azure OpenAI configuration valid"

    start_time = Time.current

    # Build system prompt with school context
    Rails.logger.info "📝 Building system prompt..."
    system_prompt = build_system_prompt(context_data)
    Rails.logger.info "📏 System prompt length: #{system_prompt.length} characters"

    # Build conversation history
    Rails.logger.info "💬 Building conversation history..."
    conversation_history = build_conversation_history
    Rails.logger.info "📚 Conversation history: #{conversation_history.length} messages"

    # API request payload for Azure OpenAI
    payload = {
      messages: [
        { role: "system", content: system_prompt },
        *conversation_history,
        { role: "user", content: user_message }
      ],
      max_tokens: 1000,
      temperature: 0.7,
      top_p: 0.9
    }
    Rails.logger.info "📦 Payload created with #{payload[:messages].length} total messages"

    # Build the API URL
    api_url = "#{azure_endpoint}/openai/deployments/#{azure_deployment}/chat/completions?api-version=2024-02-15-preview"
    Rails.logger.info "🌐 Making API request to: #{api_url}"
    Rails.logger.info "🔑 Using deployment: #{azure_deployment}"

    # Make API request to Azure OpenAI
    response = HTTParty.post(
      api_url,
      headers: {
        "api-key" => azure_api_key,
        "Content-Type" => "application/json"
      },
      body: payload.to_json,
      timeout: 30
    )

    Rails.logger.info "📡 API Response received - Status: #{response.code}"

    unless response.success?
      Rails.logger.error "❌ Azure OpenAI API Error: #{response.code}"
      Rails.logger.error "📄 Response Headers: #{response.headers.inspect}"
      Rails.logger.error "📝 Response Body: #{response.body}"

      error_details = begin
        parsed_error = response.parsed_response
        parsed_error.dig("error", "message") || response.body
      rescue => parse_error
        Rails.logger.error "🚨 Failed to parse error response: #{parse_error.message}"
        response.body
      end
      raise "Azure OpenAI API Error: #{response.code} - #{error_details}"
    end

    result = response.parsed_response
    processing_time = Time.current - start_time

    Rails.logger.info "✅ API call successful"
    Rails.logger.info "⏱️ Processing time: #{processing_time.round(2)}s"
    Rails.logger.info "🔢 Tokens used: #{result.dig('usage', 'total_tokens')}"
    Rails.logger.info "🤖 Model: #{result['model']}"
    Rails.logger.info "📄 Response length: #{result.dig('choices', 0, 'message', 'content')&.length || 0} characters"

    {
      content: result.dig("choices", 0, "message", "content"),
      model: result["model"],
      tokens_used: result.dig("usage", "total_tokens"),
      processing_time: processing_time.round(2)
    }
  end

  def build_system_prompt(context_data)
    prompt = <<~PROMPT
      You are an AI assistant helping school owners manage their school information and answer questions about their educational institution.#{' '}

      You have access to comprehensive information about #{@school.name}, including:
      - School profile and basic information
      - Academic programs, curricula, and grade offerings
      - Facilities and extracurricular activities
      - Admission requirements and fee structures
      - YouTube videos and transcript content
      - Uploaded documents and resources
      - Google Places information and reviews

      IMPORTANT GUIDELINES:
      1. Always scope your responses to THIS specific school: #{@school.name}
      2. Base your answers on the provided context data when possible
      3. If you reference information, indicate which source you're using
      4. If asked about information not in the context, clearly state you don't have that information
      5. Provide helpful, accurate, and actionable responses
      6. Suggest ways the school owner can improve their school's online presence

      AVAILABLE CONTEXT DATA:
      #{format_context_for_prompt(context_data)}

      Current date: #{Time.current.strftime('%B %d, %Y')}
      School owner: #{@user.display_name || @user.email}
    PROMPT

    prompt.strip
  end

  def format_context_for_prompt(context_data)
    return "No specific context data available." if context_data[:items].empty?

    formatted_items = context_data[:items].map do |item|
      case item[:type]
      when "school_data"
        "📋 School Data: #{item[:field]} = #{item[:value]}"
      when "document"
        "📄 Document: #{item[:title]} - #{item[:content]&.truncate(200)}"
      when "transcript"
        "🎥 Video: #{item[:title]} - #{item[:content]&.truncate(200)}"
      when "place_data"
        "📍 Location: #{item[:field]} = #{item[:value]}"
      else
        "📋 #{item[:type]}: #{item[:title]} - #{item[:content]&.truncate(200)}"
      end
    end

    formatted_items.join("\n")
  end

  def build_conversation_history(limit: 10)
    @conversation.ai_messages
                 .order(:created_at)
                 .last(limit)
                 .map do |msg|
                   {
                     role: msg.role,
                     content: msg.content
                   }
                 end
  end

  def generate_contextual_questions(school_summary, limit)
    base_questions = [
      {
        text: "Tell me about your facilities and campus features",
        metadata: { category: "facilities", priority: "high" }
      },
      {
        text: "What is the tuition and admission process?",
        metadata: { category: "admissions", priority: "high" }
      },
      {
        text: "Describe your curriculum and academic programs",
        metadata: { category: "academics", priority: "high" }
      },
      {
        text: "What extracurricular activities do you offer?",
        metadata: { category: "activities", priority: "medium" }
      },
      {
        text: "How can I improve my school's online presence?",
        metadata: { category: "marketing", priority: "medium" }
      }
    ]

    # Customize questions based on school data
    customized_questions = customize_questions_for_school(base_questions, school_summary)

    customized_questions.first(limit)
  end

  def customize_questions_for_school(base_questions, school_summary)
    questions = base_questions.dup

    # Add specific questions based on what data is missing
    if school_summary[:missing_fields].include?("curricula")
      questions.prepend({
        text: "What curricula and educational programs do you offer?",
        metadata: { category: "academics", priority: "urgent", reason: "missing_data" }
      })
    end

    if school_summary[:missing_fields].include?("facilities")
      questions.prepend({
        text: "What facilities and amenities does your school have?",
        metadata: { category: "facilities", priority: "urgent", reason: "missing_data" }
      })
    end

    if school_summary[:missing_fields].include?("grade_offerings")
      questions.prepend({
        text: "What grade levels do you serve and what are the age ranges?",
        metadata: { category: "academics", priority: "urgent", reason: "missing_data" }
      })
    end

    questions
  end

  def get_default_questions
    [
      {
        text: "Tell me about your school",
        metadata: { category: "general", priority: "high", source: "default" }
      },
      {
        text: "What makes your school unique?",
        metadata: { category: "general", priority: "medium", source: "default" }
      },
      {
        text: "How can I improve my school's profile?",
        metadata: { category: "marketing", priority: "medium", source: "default" }
      }
    ]
  end

  def generate_improvement_suggestions(gap_analysis)
    suggestions = []

    gap_analysis[:missing_fields].each do |field|
      case field
      when "description"
        suggestions << {
          field: field,
          priority: "high",
          suggestion: "Add a compelling school description that highlights your unique value proposition and educational philosophy.",
          action: "Write a 2-3 paragraph description of your school"
        }
      when "curricula"
        suggestions << {
          field: field,
          priority: "high",
          suggestion: "Specify which curricula you offer (IB, Cambridge, American, etc.) to help parents find your school.",
          action: "Select your curricula from the academic programs section"
        }
      when "facilities"
        suggestions << {
          field: field,
          priority: "medium",
          suggestion: "List your school facilities to showcase your learning environment and attract parents.",
          action: "Add facilities like library, science labs, sports fields, etc."
        }
      end
    end

    suggestions
  end

  def format_gap_analysis_response(gap_analysis, suggestions)
    content = "## School Profile Analysis\n\n"
    content += "Your school profile is **#{gap_analysis[:completeness_score]}% complete**.\n\n"

    if suggestions.any?
      content += "### Recommendations to improve your listing:\n\n"
      suggestions.each_with_index do |suggestion, index|
        content += "#{index + 1}. **#{suggestion[:field].humanize}** (#{suggestion[:priority]} priority)\n"
        content += "   #{suggestion[:suggestion]}\n"
        content += "   *Action:* #{suggestion[:action]}\n\n"
      end
    else
      content += "Great job! Your school profile looks complete. Consider adding more photos or videos to make it even more engaging.\n\n"
    end

    content += "_This analysis is based on your current school data and industry best practices._"
    content
  end

  def ai_model
    # For Azure OpenAI, we don't need to specify the model in the request
    # since it's determined by the deployment name
    nil
  end

  def azure_api_key
    ENV["AZURE_OPENAI_API_KEY"] || raise("AZURE_OPENAI_API_KEY environment variable is required")
  end

  def azure_endpoint
    ENV["AZURE_OPENAI_API_ENDPOINT"] || raise("AZURE_OPENAI_API_ENDPOINT environment variable is required")
  end

  def azure_deployment
    ENV["AZURE_OPENAI_API_DEPLOYMENT"] || raise("AZURE_OPENAI_API_DEPLOYMENT environment variable is required")
  end

  private

  def validate_azure_config
    # Ensure all required Azure OpenAI environment variables are present
    azure_api_key
    azure_endpoint
    azure_deployment

    # Validate endpoint format
    unless azure_endpoint.start_with?("https://")
      raise "AZURE_OPENAI_API_ENDPOINT must be a valid HTTPS URL"
    end
  rescue => e
    Rails.logger.error "Azure OpenAI Configuration Error: #{e.message}"
    raise "Azure OpenAI Configuration Error: #{e.message}"
  end
end
