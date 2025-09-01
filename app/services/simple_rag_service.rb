class SimpleRagService
  class << self
    # Simple Q&A using your existing RAG system
    def ask_question(place_id, question, options = {})
      Rails.logger.info "=== SimpleRagService::ask_question START ==="
      Rails.logger.info "RAG Query: #{question} for place #{place_id}"
      Rails.logger.info "Options: #{options.inspect}"
      
      # Step 1: Retrieve relevant content using your existing ContentRetrievalService
      Rails.logger.info "Step 1: Calling ContentRetrievalService.gather_context_for_blog"
      context_data = ContentRetrievalService.gather_context_for_blog(
        place_id,
        question,
        max_context_tokens: options[:max_context_tokens] || 3000,
        content_types: options[:content_types] || ['transcript', 'pdf_document']
      )
      
      Rails.logger.info "Content retrieved: content_found=#{context_data[:content_found]}, sources=#{context_data[:sources]&.length || 0}, token_count=#{context_data[:token_count]}"
      
      # Step 2: Build prompts
      Rails.logger.info "Step 2: Building prompts"
      system_prompt = build_system_prompt(options)
      user_prompt = build_user_prompt(question, context_data)
      
      Rails.logger.info "System prompt length: #{system_prompt.length} chars"
      Rails.logger.info "User prompt length: #{user_prompt.length} chars"
      
      # Step 3: Get response from AI
      Rails.logger.info "Step 3: Getting AI response"
      ai_response = get_ai_response(system_prompt, user_prompt, options)
      
      Rails.logger.info "AI response success: #{ai_response[:success]}, content length: #{ai_response[:content]&.length || 0}"
      Rails.logger.error "AI response error: #{ai_response[:error]}" if ai_response[:error]
      
      # Step 4: Format response
      sources = extract_source_info(context_data[:sources])
      Rails.logger.info "Extracted #{sources.length} sources"
      
      result = {
        success: ai_response[:success],
        answer: ai_response[:content],
        sources: sources,
        context_stats: {
          sources_found: context_data[:sources_used] || 0,
          tokens_used: context_data[:token_count] || 0,
          content_found: context_data[:content_found]
        },
        ai_usage: ai_response[:usage] || {},
        error: ai_response[:error]
      }
      
      Rails.logger.info "=== SimpleRagService::ask_question SUCCESS ==="
      Rails.logger.info "Final result success: #{result[:success]}"
      
      result
      
    rescue => e
      Rails.logger.error "=== SimpleRagService::ask_question ERROR ==="
      Rails.logger.error "SimpleRagService error: #{e.message}"
      Rails.logger.error "Backtrace:"
      Rails.logger.error e.backtrace.join("\n")
      
      {
        success: false,
        error: "Query failed: #{e.message}",
        answer: nil,
        sources: [],
        context_stats: { sources_found: 0, tokens_used: 0, content_found: false }
      }
    end
    
    # Ask multiple questions in a conversation context
    def conversation(place_id, messages, options = {})
      conversation_context = ""
      results = []
      
      messages.each_with_index do |message, index|
        if message[:role] == 'user'
          # Get RAG context for this question
          result = ask_question(place_id, message[:content], options)
          
          # Add to conversation context for next questions
          if result[:success] && result[:context_stats][:content_found]
            conversation_context += "\n\nPrevious context: #{message[:content]} - #{result[:answer]}"
          end
          
          results << {
            question: message[:content],
            result: result,
            turn: index
          }
        end
      end
      
      {
        conversation_results: results,
        total_sources_used: results.sum { |r| r.dig(:result, :context_stats, :sources_found) || 0 }
      }
    end
    
    # Preview what content would be used for a question (without AI call)
    def preview_context(place_id, question, options = {})
      context_data = ContentRetrievalService.gather_context_for_blog(
        place_id,
        question,
        max_context_tokens: options[:preview_tokens] || 1000,
        content_types: options[:content_types] || ['transcript', 'pdf_document']
      )
      
      {
        question: question,
        content_found: context_data[:content_found],
        sources: extract_source_info(context_data[:sources]),
        context_preview: context_data[:context]&.truncate(800),
        stats: {
          sources_found: context_data[:sources_used] || 0,
          tokens_used: context_data[:token_count] || 0
        }
      }
    end
    
    private
    
    def build_system_prompt(options = {})
      style = options[:style] || 'helpful'
      
      base_prompt = <<~PROMPT
        You are a knowledgeable assistant answering questions about an educational institution.
        
        CRITICAL RULES:
        - Answer ONLY using information from the provided context
        - If the context doesn't contain enough information, say "I don't have enough information in the available content to answer that question."
        - Always cite specific sources when referencing information (e.g., "According to the video 'School Tour'..." or "From the document about admissions...")
        - Be accurate and never make up information
        - Keep responses concise but informative
      PROMPT
      
      case style
      when 'formal'
        base_prompt += "\n- Use formal, professional language suitable for official communications"
      when 'friendly'
        base_prompt += "\n- Use warm, friendly language as if talking to prospective parents"
      when 'detailed'
        base_prompt += "\n- Provide comprehensive answers with specific examples from the context"
      end
      
      base_prompt
    end
    
    def build_user_prompt(question, context_data)
      prompt = "Question: #{question}\n\n"
      
      if context_data[:content_found]
        prompt += "Available information from school content:\n"
        prompt += "#{context_data[:context]}\n\n"
        prompt += "Please answer the question using only the information provided above. "
        prompt += "Cite specific sources (video titles, documents) when referencing information."
      else
        prompt += "No relevant information found in the school's available content.\n\n"
        prompt += "Please indicate that you don't have enough information to answer this question."
      end
      
      prompt
    end
    
    def get_ai_response(system_prompt, user_prompt, options = {})
      # Choose AI service based on options or availability
      ai_service = options[:ai_service] || detect_available_ai_service
      
      Rails.logger.info "Selected AI service: #{ai_service || 'NONE'}"
      
      case ai_service
      when 'azure_openai'
        Rails.logger.info "Using Azure OpenAI service"
        use_azure_openai(system_prompt, user_prompt, options)
      when 'openai'
        Rails.logger.info "Using direct OpenAI service"
        use_openai_direct(system_prompt, user_prompt, options)
      else
        Rails.logger.error "No AI service available - check API keys"
        { success: false, error: "No AI service available" }
      end
    end
    
    def detect_available_ai_service
      azure_key = ENV['AZURE_OPENAI_API_KEY'].present?
      azure_endpoint = ENV['AZURE_OPENAI_ENDPOINT'].present?
      azure_deployment = (ENV['AZURE_OPENAI_API_DEPLOYMENT'] || ENV['AZURE_OPENAI_DEPLOYMENT']).present?
      openai_key = ENV['OPENAI_API_KEY'].present?
      
      azure_fully_configured = azure_key && azure_endpoint && azure_deployment
      
      Rails.logger.info "AI service detection:"
      Rails.logger.info "  Azure OpenAI: key=#{azure_key}, endpoint=#{azure_endpoint}, deployment=#{azure_deployment} (fully_configured=#{azure_fully_configured})"
      Rails.logger.info "  OpenAI: key=#{openai_key}"
      
      return 'azure_openai' if azure_fully_configured
      return 'openai' if openai_key
      nil
    end
    
    def use_azure_openai(system_prompt, user_prompt, options = {})
      azure_service = AzureOpenaiService.new
      result = azure_service.send(:make_chat_request, system_prompt, user_prompt, {
        max_tokens: options[:max_tokens] || 800,
        temperature: options[:temperature] || 0.3
      })
      
      if result.success?
        content = result.dig('choices', 0, 'message', 'content')
        {
          success: true,
          content: content,
          usage: result['usage']
        }
      else
        {
          success: false,
          error: "Azure OpenAI error: #{result.code} - #{result.message}"
        }
      end
      
    rescue => e
      {
        success: false,
        error: "Azure OpenAI exception: #{e.message}"
      }
    end
    
    def use_openai_direct(system_prompt, user_prompt, options = {})
      require 'net/http'
      require 'uri'
      require 'json'
      
      uri = URI('https://api.openai.com/v1/chat/completions')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{ENV['OPENAI_API_KEY']}"
      request['Content-Type'] = 'application/json'
      
      request.body = {
        model: options[:model] || 'gpt-4o-mini',
        messages: [
          { role: 'system', content: system_prompt },
          { role: 'user', content: user_prompt }
        ],
        max_tokens: options[:max_tokens] || 800,
        temperature: options[:temperature] || 0.3
      }.to_json
      
      response = http.request(request)
      
      if response.code == '200'
        data = JSON.parse(response.body)
        {
          success: true,
          content: data.dig('choices', 0, 'message', 'content'),
          usage: data['usage']
        }
      else
        {
          success: false,
          error: "OpenAI API error: #{response.code} - #{response.message}"
        }
      end
      
    rescue => e
      {
        success: false,
        error: "OpenAI exception: #{e.message}"
      }
    end
    
    def extract_source_info(sources)
      return [] unless sources.present?
      
      sources.map do |source|
        {
          type: source[:type],
          title: source[:source],
          relevance_score: source[:relevance_score]&.round(3),
          metadata: {
            created_at: source.dig(:metadata, :created_at),
            content_type: source.dig(:metadata, :content_type) || 'transcript'
          }
        }
      end
    end
  end
end