class ContentRetrievalService
  class << self
    def gather_context_for_blog(place_id, topic, options = {})
      max_tokens = options[:max_context_tokens] || 4000
      content_types = options[:content_types] || ['transcript', 'pdf_document', 'text_document']
      
      Rails.logger.info "Gathering context for place #{place_id}, topic: '#{topic}'"
      Rails.logger.info "Content types: #{content_types.join(', ')}, max tokens: #{max_tokens}"
      
      # Step 1: Vector similarity search
      relevant_content = find_relevant_content(place_id, topic, content_types)
      
      if relevant_content.empty?
        Rails.logger.warn "No relevant content found for place #{place_id} and topic '#{topic}'"
        return {
          context: '',
          sources: [],
          token_count: 0,
          content_found: false
        }
      end
      
      Rails.logger.info "Found #{relevant_content.length} relevant content items"
      
      # Step 2: Rank and filter content by relevance
      ranked_content = rank_content_by_relevance(relevant_content, topic)
      
      # Step 3: Build context within token limits
      context_data = build_context_string(ranked_content, max_tokens)
      
      Rails.logger.info "Built context with #{context_data[:token_count]} tokens from #{context_data[:sources_used]} sources"
      
      {
        context: context_data[:context],
        sources: extract_source_metadata(ranked_content),
        token_count: context_data[:token_count],
        sources_used: context_data[:sources_used],
        content_found: true
      }
    end
    
    private
    
    def find_relevant_content(place_id, topic, content_types)
      # Generate embedding for the topic/query
      topic_embedding = EmbeddingService.generate_embedding(topic)
      return [] unless topic_embedding
      
      results = []
      
      # Search transcripts if requested
      if content_types.include?('transcript')
        results += search_transcripts(place_id, topic_embedding)
        results += search_transcript_segments(place_id, topic_embedding)
      end
      
      # Search documents if requested
      document_types = content_types & ['pdf_document', 'text_document', 'uploaded_file']
      if document_types.any?
        results += search_documents(place_id, topic_embedding, document_types)
      end
      
      results
    end
    
    def search_transcripts(place_id, topic_embedding)
      transcripts = Transcript.for_place(place_id)
                            .with_embeddings
                            .similar_to(topic_embedding, 5)
                            .includes(:place)
      
      transcripts.map do |transcript|
        {
          type: 'transcript',
          id: transcript.id,
          source: "Video: #{transcript.video_title}",
          content: transcript.full_transcript_text,
          metadata: {
            video_title: transcript.video_title,
            video_url: transcript.video_url,
            duration: transcript.total_duration_ms,
            place_name: transcript.place.name,
            created_at: transcript.created_at
          },
          relevance_score: calculate_vector_distance(transcript.embedding, topic_embedding),
          content_length: transcript.full_transcript_text&.length || 0
        }
      end
    end
    
    def search_transcript_segments(place_id, topic_embedding)
      segments = TranscriptSegment.joins(:transcript)
                                 .where(transcript: { place_id: place_id })
                                 .with_embeddings
                                 .similar_to(topic_embedding, 10)
                                 .includes(transcript: :place)
      
      segments.map do |segment|
        {
          type: 'transcript_segment',
          id: segment.id,
          source: "Video: #{segment.transcript.video_title} (#{segment.timestamp_formatted})",
          content: segment.text,
          metadata: {
            video_title: segment.transcript.video_title,
            video_url: segment.transcript.video_url,
            timestamp: segment.offset_ms,
            timestamp_formatted: segment.timestamp_formatted,
            place_name: segment.transcript.place.name,
            created_at: segment.created_at
          },
          relevance_score: calculate_vector_distance(segment.embedding, topic_embedding),
          content_length: segment.text&.length || 0
        }
      end
    end
    
    def search_documents(place_id, topic_embedding, document_types)
      documents = DocumentContent.for_place(place_id)
                                .where(content_type: document_types)
                                .with_embeddings
                                .similar_to(topic_embedding, 10)
                                .includes(:place)
      
      documents.map do |document|
        {
          type: 'document',
          id: document.id,
          source: "Document: #{document.title}",
          content: document.processed_text,
          metadata: {
            title: document.title,
            content_type: document.content_type,
            file_size: document.file_size_formatted,
            place_name: document.place.name,
            created_at: document.created_at,
            processing_metadata: document.metadata
          },
          relevance_score: calculate_vector_distance(document.embedding, topic_embedding),
          content_length: document.processed_text&.length || 0
        }
      end
    end
    
    def rank_content_by_relevance(content, topic)
      keyword_phrases = extract_key_phrases(topic)
      
      ranked_content = content.map do |item|
        base_score = 1.0 / (1.0 + item[:relevance_score]) # Convert distance to similarity
        
        # Boost recent content (within last 6 months gets bonus)
        if item[:metadata][:created_at]
          months_old = (Time.current - item[:metadata][:created_at]) / 1.month
          recency_boost = months_old < 6 ? 0.2 * (1 - months_old / 6) : 0
          base_score += recency_boost
        end
        
        # Boost content with topic keywords
        keyword_boost = calculate_keyword_boost(item[:content], keyword_phrases)
        base_score += keyword_boost * 0.3
        
        # Boost longer content (more comprehensive)
        length_boost = [item[:content_length] / 2000.0, 0.2].min
        base_score += length_boost
        
        # Boost transcripts over segments for comprehensive context
        type_boost = case item[:type]
                    when 'transcript' then 0.1
                    when 'document' then 0.05
                    when 'transcript_segment' then 0.0
                    else 0.0
                    end
        base_score += type_boost
        
        item.merge(final_score: base_score)
      end
      
      ranked_content.sort_by { |item| -item[:final_score] }
    end
    
    def build_context_string(ranked_content, max_tokens)
      context_parts = []
      current_tokens = 0
      sources_used = 0
      
      ranked_content.each do |item|
        # Format content with source attribution
        content_text = format_content_for_context(item)
        content_tokens = EmbeddingService.estimate_tokens(content_text)
        
        # Check if adding this content would exceed token limit
        if current_tokens + content_tokens > max_tokens
          # Try to fit a truncated version
          remaining_tokens = max_tokens - current_tokens - 50 # Leave buffer
          if remaining_tokens > 200 # Only truncate if we have reasonable space
            truncated_text = EmbeddingService.truncate_text(item[:content], remaining_tokens - 100)
            truncated_content = format_content_for_context(item.merge(content: truncated_text))
            context_parts << truncated_content
            current_tokens += EmbeddingService.estimate_tokens(truncated_content)
            sources_used += 1
          end
          break
        end
        
        context_parts << content_text
        current_tokens += content_tokens
        sources_used += 1
      end
      
      {
        context: context_parts.join("\n\n"),
        token_count: current_tokens,
        sources_used: sources_used
      }
    end
    
    def format_content_for_context(item)
      case item[:type]
      when 'transcript'
        "VIDEO TRANSCRIPT: #{item[:source]}\nContent: #{item[:content]}"
      when 'transcript_segment'
        "VIDEO SEGMENT: #{item[:source]}\nContent: #{item[:content]}"
      when 'document'
        "DOCUMENT: #{item[:source]}\nContent: #{item[:content]}"
      else
        "SOURCE: #{item[:source]}\nContent: #{item[:content]}"
      end
    end
    
    def extract_source_metadata(content)
      content.map do |item|
        {
          id: item[:id],
          type: item[:type],
          source: item[:source],
          metadata: item[:metadata],
          relevance_score: item[:relevance_score],
          final_score: item[:final_score]
        }
      end
    end
    
    def extract_key_phrases(topic)
      # Simple keyword extraction - in production, you might use more sophisticated NLP
      words = topic.downcase
                  .gsub(/[^\w\s]/, ' ')
                  .split(/\s+/)
                  .reject { |w| w.length < 3 }
      
      # Remove common stop words
      stop_words = %w[the and or but for with are was were been have has had will would could should]
      words - stop_words
    end
    
    def calculate_keyword_boost(content, keyword_phrases)
      return 0 if content.blank? || keyword_phrases.empty?
      
      content_lower = content.downcase
      matches = keyword_phrases.count { |phrase| content_lower.include?(phrase) }
      
      matches.to_f / keyword_phrases.length
    end
    
    def calculate_vector_distance(embedding1, embedding2)
      # PostgreSQL returns the cosine distance, which is what we want
      # Lower distance = higher similarity
      return 1.0 if embedding1.nil? || embedding2.nil?
      
      # This is a placeholder - in actual queries, PostgreSQL calculates this
      0.5
    end
  end
end