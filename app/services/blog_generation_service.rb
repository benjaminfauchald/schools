class BlogGenerationService
  class << self
    def generate_for_place(place_id, topic, options = {})
      place = Place.find(place_id)
      
      Rails.logger.info "Starting blog generation for place #{place_id} (#{place.name}), topic: '#{topic}'"
      
      # Validate inputs
      return validation_error("Topic cannot be blank") if topic.blank?
      return validation_error("Place not found") unless place
      
      # Step 1: Gather relevant content using RAG
      Rails.logger.info "Step 1: Gathering context for blog topic"
      context_data = ContentRetrievalService.gather_context_for_blog(
        place_id, 
        topic,
        max_context_tokens: options[:max_context_tokens] || 6000,
        content_types: options[:content_types] || ['transcript', 'pdf_document', 'text_document']
      )
      
      # Check if we found any content
      unless context_data[:content_found]
        Rails.logger.warn "No relevant content found for topic '#{topic}' at place #{place_id}"
        return {
          success: false, 
          error: 'No relevant content found for this topic. Please ensure there are transcripts or documents available that relate to this subject.',
          context_attempted: true,
          place_name: place.name
        }
      end
      
      Rails.logger.info "Step 2: Content retrieved - #{context_data[:token_count]} tokens from #{context_data[:sources_used]} sources"
      
      # Step 2: Generate blog post with Azure OpenAI
      Rails.logger.info "Step 3: Generating blog post with Azure OpenAI"
      azure_service = AzureOpenAIService.new
      generation_result = azure_service.generate_blog_post(
        place, 
        topic, 
        context_data,
        word_count: options[:word_count] || 800,
        tone: options[:tone] || extract_place_tone(place),
        audience: options[:audience] || 'parents and students',
        max_tokens: options[:max_response_tokens] || 2000,
        temperature: options[:temperature] || 0.7
      )
      
      # Step 3: Handle generation result
      if generation_result[:success]
        Rails.logger.info "Step 4: Blog post generated successfully, creating record"
        blog_post = create_blog_post_record(place, topic, generation_result, context_data, options)
        
        if blog_post
          Rails.logger.info "Blog post created successfully with ID #{blog_post.id}"
          
          {
            success: true,
            blog_post: blog_post,
            sources_used: context_data[:sources],
            content_stats: {
              tokens_used: generation_result[:usage],
              context_token_count: context_data[:token_count],
              sources_count: context_data[:sources_used],
              generated_content_length: generation_result[:content]&.length || 0
            },
            generation_metadata: {
              topic: topic,
              word_count: options[:word_count] || 800,
              tone: options[:tone] || extract_place_tone(place),
              audience: options[:audience] || 'parents and students',
              finish_reason: generation_result[:finish_reason]
            }
          }
        else
          {
            success: false,
            error: 'Failed to save blog post to database',
            generation_successful: true
          }
        end
      else
        Rails.logger.error "Blog generation failed: #{generation_result[:error]}"
        
        {
          success: false,
          error: generation_result[:error],
          error_code: generation_result[:error_code],
          context_data: context_data,
          azure_openai_error: true,
          place_name: place.name
        }
      end
      
    rescue ActiveRecord::RecordNotFound
      validation_error("Place with ID #{place_id} not found")
    rescue => e
      Rails.logger.error "Unexpected error in blog generation: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      {
        success: false,
        error: "An unexpected error occurred: #{e.message}",
        error_type: e.class.name,
        place_id: place_id,
        topic: topic
      }
    end
    
    def suggest_topics_for_place(place_id, options = {})
      place = Place.find(place_id)
      limit = options[:limit] || 10
      
      Rails.logger.info "Generating topic suggestions for place #{place_id}"
      
      # Get content statistics
      transcript_count = Transcript.for_place(place_id).processed.count
      document_count = DocumentContent.for_place(place_id).completed.count
      
      if transcript_count == 0 && document_count == 0
        return {
          success: false,
          error: "No processed content available for topic suggestions. Please upload and process transcripts or documents first.",
          suggestions: []
        }
      end
      
      # Generate suggestions based on content analysis
      suggestions = []
      
      # General educational topics that work well with most content
      suggestions.concat([
        "Our Educational Philosophy and Teaching Approach",
        "Student Life and Campus Culture", 
        "Academic Programs and Curriculum Excellence",
        "Faculty Expertise and Teaching Quality",
        "Learning Environment and Facilities",
        "Student Support Services and Resources"
      ])
      
      # Add content-specific suggestions if we have transcripts
      if transcript_count > 0
        # Analyze recent transcript titles for topic ideas
        recent_transcripts = Transcript.for_place(place_id)
                                     .processed
                                     .order(created_at: :desc)
                                     .limit(5)
                                     .pluck(:video_title)
        
        # Extract topics from video titles
        title_topics = extract_topics_from_titles(recent_transcripts)
        suggestions.concat(title_topics)
      end
      
      # Add document-based suggestions
      if document_count > 0
        suggestions.concat([
          "Key Information from Our Documents",
          "Important Policies and Procedures", 
          "Resources and Guidelines for Students"
        ])
      end
      
      # Add place-specific suggestions based on type
      if place.is_school?
        suggestions.concat([
          "Admissions Process and Requirements",
          "Extracurricular Activities and Programs",
          "Parent and Community Involvement",
          "Academic Achievement and Success Stories"
        ])
      end
      
      # Remove duplicates and limit results
      unique_suggestions = suggestions.uniq.first(limit)
      
      {
        success: true,
        suggestions: unique_suggestions.map.with_index do |topic, index|
          {
            id: index + 1,
            topic: topic,
            estimated_content_available: estimate_content_availability(place_id, topic)
          }
        end,
        content_stats: {
          transcript_count: transcript_count,
          document_count: document_count,
          total_content_items: transcript_count + document_count
        }
      }
    end
    
    def preview_context_for_topic(place_id, topic, options = {})
      # This method allows users to preview what content would be used
      # before generating a full blog post
      
      context_data = ContentRetrievalService.gather_context_for_blog(
        place_id,
        topic,
        max_context_tokens: options[:preview_tokens] || 1000,
        content_types: options[:content_types] || ['transcript', 'pdf_document', 'text_document']
      )
      
      {
        topic: topic,
        content_found: context_data[:content_found],
        sources_count: context_data[:sources_used] || 0,
        token_count: context_data[:token_count] || 0,
        sources_preview: context_data[:sources]&.first(3)&.map do |source|
          {
            type: source[:type],
            source: source[:source],
            relevance_score: source[:relevance_score]&.round(3)
          }
        end || [],
        context_preview: context_data[:context]&.truncate(500) || '',
        recommendations: generate_topic_recommendations(context_data)
      }
    end
    
    private
    
    def validation_error(message)
      {
        success: false,
        error: message,
        validation_error: true
      }
    end
    
    def extract_place_tone(place)
      # Check if place has tone preference
      if place.respond_to?(:preferences) && place.preferences&.dig('tone_of_voice').present?
        place.preferences['tone_of_voice']
      elsif place.is_school?
        'informative and welcoming'
      else
        'professional and informative'
      end
    end
    
    def create_blog_post_record(place, topic, generation_result, context_data, options)
      # Extract title from generated content
      title = extract_title_from_content(generation_result[:content]) || "#{topic} - #{place.name}"
      
      # Create the page record (assuming you have a pages model for blog posts)
      page_data = {
        title: title,
        content: generation_result[:content],
        page_type: 'blog_post',
        published_at: options[:publish_immediately] ? Time.current : nil,
        metadata: {
          blog_generation: {
            topic: topic,
            sources_used: context_data[:sources],
            generation_timestamp: Time.current,
            tokens_used: generation_result[:usage],
            context_token_count: context_data[:token_count],
            generation_options: {
              word_count: options[:word_count] || 800,
              tone: options[:tone] || extract_place_tone(place),
              audience: options[:audience] || 'parents and students'
            },
            finish_reason: generation_result[:finish_reason],
            model_used: generation_result[:model]
          }
        }.to_json
      }
      
      if place.respond_to?(:pages)
        place.pages.create!(page_data)
      else
        # Fallback: create a generic content record
        # You might need to adjust this based on your actual model structure
        Rails.logger.warn "Place model doesn't have pages association, creating generic record"
        
        # This is a placeholder - adjust based on your actual content model
        {
          id: SecureRandom.uuid,
          title: title,
          content: generation_result[:content],
          place: place,
          created_at: Time.current
        }
      end
      
    rescue => e
      Rails.logger.error "Failed to create blog post record: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    end
    
    def extract_title_from_content(content)
      return nil if content.blank?
      
      # Look for common title patterns at the beginning
      lines = content.lines.map(&:strip).reject(&:empty?)
      return nil if lines.empty?
      
      first_line = lines.first
      
      # Check if first line looks like a title (not too long, possibly has markdown formatting)
      if first_line.length <= 100 && (first_line.start_with?('#') || first_line.match(/^[A-Z]/))
        # Remove markdown formatting
        title = first_line.gsub(/^#+\s*/, '').gsub(/\*\*(.+?)\*\*/, '\\1').strip
        return title if title.present?
      end
      
      nil
    end
    
    def extract_topics_from_titles(titles)
      return [] if titles.blank?
      
      # Simple topic extraction from video titles
      # In production, you might use more sophisticated NLP
      
      topics = []
      
      titles.each do |title|
        # Look for common educational keywords and themes
        if title.match(/curriculum|program|course/i)
          topics << "Our Curriculum and Academic Programs"
        elsif title.match(/student|campus|life/i)
          topics << "Student Life and Campus Experience"
        elsif title.match(/faculty|teacher|staff/i)
          topics << "Meet Our Faculty and Staff"
        elsif title.match(/facility|building|campus/i)
          topics << "Our Facilities and Learning Environment"
        elsif title.match(/admission|enroll|application/i)
          topics << "Admissions and Enrollment Process"
        end
      end
      
      topics.uniq
    end
    
    def estimate_content_availability(place_id, topic)
      # Quick estimation of content availability for a topic
      # This is a simplified version - you could make this more sophisticated
      
      content_count = 0
      
      # Count transcripts that might contain relevant content
      content_count += Transcript.for_place(place_id).processed.count
      
      # Count documents
      content_count += DocumentContent.for_place(place_id).completed.count
      
      case content_count
      when 0
        'No content'
      when 1..2
        'Limited content'
      when 3..5
        'Some content'  
      when 6..10
        'Good content'
      else
        'Rich content'
      end
    end
    
    def generate_topic_recommendations(context_data)
      recommendations = []
      
      if context_data[:sources_used] == 0
        recommendations << "Consider uploading more content related to this topic"
        recommendations << "Add transcripts from videos about this subject"
        recommendations << "Upload relevant documents or PDFs"
      elsif context_data[:sources_used] < 3
        recommendations << "Limited content found - consider adding more sources"
        recommendations << "Try a broader topic to capture more content"
      else
        recommendations << "Good content available for this topic"
        recommendations << "Consider related topics that might have additional content"
      end
      
      recommendations
    end
  end
end