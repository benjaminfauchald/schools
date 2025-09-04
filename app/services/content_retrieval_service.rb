# Content Retrieval Service for RAG (Retrieval-Augmented Generation)
# Aggregates and searches through school-specific data for AI context
class ContentRetrievalService
  def initialize(school)
    @school = school
    @place = school.place
    @document_search = DocumentSearchService.new(school)
  end
  
  # Main method to retrieve relevant context for a user query
  def retrieve_context(query, options = {})
    max_items = options[:max_items] || 10
    include_embeddings = options[:include_embeddings] || false
    
    context_items = []
    source_references = []
    
    # Search across different data sources
    context_items.concat(search_school_data(query, limit: 3))
    context_items.concat(search_documents(query, limit: 3))
    context_items.concat(search_transcripts(query, limit: 3))
    context_items.concat(search_place_data(query, limit: 2))
    
    # Sort by relevance and take top items
    relevant_items = context_items.sort_by { |item| -item[:relevance_score] }
                                  .first(max_items)
    
    # Build source references for attribution
    source_references = build_source_references(relevant_items)
    
    {
      query: query,
      items: relevant_items,
      items_used: relevant_items.count,
      source_references: source_references,
      data_sources: {
        school_data: context_items.count { |item| item[:type] == 'school_data' },
        documents: context_items.count { |item| item[:type] == 'document' },
        transcripts: context_items.count { |item| item[:type] == 'transcript' },
        place_data: context_items.count { |item| item[:type] == 'place_data' }
      }
    }
  end
  
  # Generate a summary of school data for context
  def generate_school_summary
    {
      basic_info: extract_basic_info,
      academic_info: extract_academic_info,
      facilities_info: extract_facilities_info,
      contact_info: extract_contact_info,
      completeness_score: calculate_completeness_score,
      missing_fields: identify_missing_fields,
      last_updated: @school.updated_at
    }
  end
  
  # Analyze data completeness and identify gaps
  def analyze_data_completeness
    required_fields = %w[description curricula facilities grade_offerings contact_info]
    optional_fields = %w[extracurriculars accreditations photos videos documents]
    
    missing_required = []
    missing_optional = []
    
    required_fields.each do |field|
      missing_required << field unless field_complete?(field)
    end
    
    optional_fields.each do |field|
      missing_optional << field unless field_complete?(field)
    end
    
    completeness_score = calculate_detailed_completeness_score
    
    {
      completeness_score: completeness_score,
      missing_fields: missing_required + missing_optional,
      critical_missing: missing_required,
      optional_missing: missing_optional,
      recommendations: generate_field_recommendations(missing_required, missing_optional),
      source_references: build_completeness_source_references
    }
  end
  
  private
  
  def search_school_data(query, limit: 5)
    items = []
    query_terms = query.downcase.split
    
    # Search in school about text
    if @school.about.present? && matches_query?(@school.about, query_terms)
      items << {
        type: 'school_data',
        field: 'about',
        title: 'School Description',
        content: @school.about,
        value: @school.about,
        relevance_score: calculate_text_relevance(@school.about, query_terms)
      }
    end
    
    # Search in academic programs
    academic_text = build_academic_text
    if academic_text.present? && matches_query?(academic_text, query_terms)
      items << {
        type: 'school_data',
        field: 'academic_programs',
        title: 'Academic Programs',
        content: academic_text,
        value: academic_text,
        relevance_score: calculate_text_relevance(academic_text, query_terms)
      }
    end
    
    # Search in facilities
    facilities_text = build_facilities_text
    if facilities_text.present? && matches_query?(facilities_text, query_terms)
      items << {
        type: 'school_data',
        field: 'facilities',
        title: 'School Facilities',
        content: facilities_text,
        value: facilities_text,
        relevance_score: calculate_text_relevance(facilities_text, query_terms)
      }
    end
    
    # Search in fee information
    fee_text = build_fee_text
    if fee_text.present? && matches_query?(fee_text, query_terms)
      items << {
        type: 'school_data',
        field: 'fees',
        title: 'Tuition and Fees',
        content: fee_text,
        value: fee_text,
        relevance_score: calculate_text_relevance(fee_text, query_terms)
      }
    end
    
    items.first(limit)
  end
  
  def search_documents(query, limit: 5)
    return [] unless @place
    
    document_results = @document_search.search_by_text(query, limit: limit)
    
    document_results[:results].map do |doc|
      # Extract relevant excerpt from the document
      relevant_excerpt = extract_relevant_document_excerpt(doc.extracted_text, query, max_length: 800)
      
      {
        type: 'document',
        id: doc.id,
        title: doc.filename,
        content: relevant_excerpt,
        relevance_score: calculate_document_relevance_score(doc.extracted_text, query),
        metadata: {
          file_type: doc.file_type_display,
          file_size: doc.file_size_display,
          created_at: doc.created_at
        }
      }
    end
  end
  
  def search_transcripts(query, limit: 5)
    return [] unless @place&.transcripts&.any?
    
    # Try vector search first if embeddings are available
    vector_items = search_transcripts_by_vector(query, limit: limit * 2)
    
    # Fallback to text search if vector search yields insufficient results
    if vector_items.length < limit / 2
      Rails.logger.debug "🔍 Vector search yielded #{vector_items.length} results, falling back to text search"
      text_items = search_transcripts_by_text(query, limit: limit)
      
      # Combine results, prioritizing vector results
      all_items = (vector_items + text_items).uniq { |item| [item[:type], item[:id]] }
      return all_items.first(limit)
    end
    
    vector_items.first(limit)
  end

  def search_transcripts_by_vector(query, limit: 10)
    return [] unless query.present?
    
    begin
      # Generate embedding for the search query
      embedding_service = EmbeddingGenerationService.new
      query_embedding = embedding_service.generate_embedding(query)
      
      return [] unless query_embedding
      
      items = []
      
      # Search transcript segments using vector similarity
      Rails.logger.debug "🔮 Performing vector similarity search for transcripts"
      
      # Get all transcript segments from this place's transcripts
      place_transcript_ids = @place.transcripts.processed.ai_enabled.with_embeddings.pluck(:id)
      return [] if place_transcript_ids.empty?
      
      similar_segments = TranscriptSegment.by_transcript_ids(place_transcript_ids)
                                        .find_similar_segments(query_embedding, 
                                                              limit: limit, 
                                                              similarity_threshold: 0.7)
      
      similar_segments.each do |segment|
        transcript = segment.transcript
        items << {
          type: 'transcript_segment',
          id: segment.id,
          title: "#{transcript.video_title} (#{segment.time_range_display})",
          content: segment.text,
          video_id: transcript.video_id,
          youtube_url: segment.youtube_url_with_timestamp,
          start_time: segment.start_time,
          end_time: segment.end_time,
          relevance_score: segment.respond_to?(:similarity) ? segment.similarity.to_f : 0.8,
          search_method: 'vector'
        }
      end
      
      # Also search full transcripts if they have embeddings
      @place.transcripts.processed.ai_enabled.with_embeddings.each do |transcript|
        # Skip if we already have segments from this transcript
        next if items.any? { |item| item[:video_id] == transcript.video_id }
        
        # For full transcripts, we'd need to implement similarity search at transcript level
        # For now, we'll rely on segment-level search which is more granular
      end
      
      Rails.logger.debug "🔮 Vector search found #{items.length} results"
      items.sort_by { |item| -item[:relevance_score] }
      
    rescue => e
      Rails.logger.error "❌ Vector search failed: #{e.message}"
      Rails.logger.error e.backtrace.first(3).join("\n")
      []
    end
  end

  def search_transcripts_by_text(query, limit: 5)
    return [] unless @place&.transcripts&.any?
    
    items = []
    query_terms = query.downcase.split
    
    @place.transcripts.processed.ai_enabled.each do |transcript|
      # Search in full transcript
      if transcript.full_transcript.present? && matches_query?(transcript.full_transcript, query_terms)
        items << {
          type: 'transcript',
          id: transcript.id,
          title: transcript.video_title || "Video #{transcript.video_id}",
          content: extract_relevant_transcript_excerpt(transcript.full_transcript, query_terms),
          video_id: transcript.video_id,
          youtube_url: transcript.youtube_url,
          relevance_score: calculate_text_relevance(transcript.full_transcript, query_terms),
          search_method: 'text'
        }
      end
      
      # Search in transcript segments for more precise matches
      transcript.transcript_segments.each do |segment|
        if matches_query?(segment.text, query_terms)
          items << {
            type: 'transcript_segment',
            id: segment.id,
            title: "#{transcript.video_title} (#{segment.time_range_display})",
            content: segment.text,
            video_id: transcript.video_id,
            youtube_url: segment.youtube_url_with_timestamp,
            start_time: segment.start_time,
            end_time: segment.end_time,
            relevance_score: calculate_text_relevance(segment.text, query_terms) + 0.1, # Bonus for segment precision
            search_method: 'text'
          }
        end
      end
    end
    
    items.sort_by { |item| -item[:relevance_score] }.first(limit)
  end
  
  def search_place_data(query, limit: 3)
    return [] unless @place
    
    items = []
    query_terms = query.downcase.split
    
    # Search in place description/editorial summary
    if @place.editorial_summary.present? && matches_query?(@place.editorial_summary, query_terms)
      items << {
        type: 'place_data',
        field: 'editorial_summary',
        title: 'Location Description',
        content: @place.editorial_summary,
        value: @place.editorial_summary,
        relevance_score: calculate_text_relevance(@place.editorial_summary, query_terms)
      }
    end
    
    # Search in reviews
    if @place.reviews.present?
      relevant_reviews = @place.reviews.select { |review| 
        matches_query?(review['text'], query_terms) if review['text']
      }.first(2)
      
      relevant_reviews.each do |review|
        items << {
          type: 'place_data',
          field: 'reviews',
          title: "Google Review (#{review['rating']} stars)",
          content: review['text'],
          value: review['text'],
          relevance_score: calculate_text_relevance(review['text'], query_terms),
          metadata: {
            rating: review['rating'],
            author: review['author_name'],
            time: review['time']
          }
        }
      end
    end
    
    items.first(limit)
  end
  
  def build_source_references(items)
    items.map do |item|
      case item[:type]
      when 'school_data'
        {
          type: 'school_data',
          field_name: item[:field],
          title: item[:title],
          description: "School profile information"
        }
      when 'document'
        {
          type: 'document',
          id: item[:id],
          title: item[:title],
          description: "Uploaded document: #{item[:metadata][:file_type]}"
        }
      when 'transcript'
        {
          type: 'transcript',
          id: item[:id],
          video_id: item[:video_id],
          video_title: item[:title],
          youtube_url: item[:youtube_url],
          description: "YouTube video transcript"
        }
      when 'transcript_segment'
        {
          type: 'transcript_segment',
          id: item[:id],
          video_id: item[:video_id],
          video_title: item[:title],
          youtube_url: item[:youtube_url],
          start_time: item[:start_time],
          end_time: item[:end_time],
          description: "Video transcript segment"
        }
      when 'place_data'
        {
          type: 'place_data',
          field_name: item[:field],
          title: item[:title],
          description: "Google Places information"
        }
      end
    end
  end
  
  # Helper methods for data extraction
  
  def extract_basic_info
    {
      name: @school.name,
      description: @school.about,
      address: @school.display_address,
      phone: @school.display_phone,
      website: @school.display_website,
      email: @school.email
    }
  end
  
  def extract_academic_info
    {
      curricula: @school.curricula.pluck(:label),
      accreditations: @school.accreditations.pluck(:label),
      grade_levels: @school.grade_levels,
      age_range: @school.age_range,
      educational_level: @school.educational_level
    }
  end
  
  def extract_facilities_info
    {
      facilities: @school.facilities.pluck(:label),
      boarding: @school.boarding?,
      school_bus: @school.school_bus?
    }
  end
  
  def extract_contact_info
    {
      formatted_address: @place&.formatted_address,
      phone: @place&.formatted_phone_number,
      website: @place&.website,
      opening_hours: @place&.opening_hours
    }
  end
  
  def calculate_completeness_score
    total_fields = 10
    completed_fields = 0
    
    completed_fields += 1 if @school.about.present?
    completed_fields += 1 if @school.curricula.any?
    completed_fields += 1 if @school.facilities.any?
    completed_fields += 1 if @school.school_grade_offering.present?
    completed_fields += 1 if @school.current_fee_schedule.present?
    completed_fields += 1 if @school.email.present?
    completed_fields += 1 if @school.display_phone.present?
    completed_fields += 1 if @school.display_website.present?
    completed_fields += 1 if @place&.photos&.any?
    completed_fields += 1 if @school.youtube_videos_from_database.any?
    
    (completed_fields.to_f / total_fields * 100).round
  end
  
  def identify_missing_fields
    missing = []
    
    missing << 'description' unless @school.about.present?
    missing << 'curricula' unless @school.curricula.any?
    missing << 'facilities' unless @school.facilities.any?
    missing << 'grade_offerings' unless @school.school_grade_offering.present?
    missing << 'contact_info' unless @school.email.present? && @school.display_phone.present?
    missing << 'photos' unless @place&.photos&.any?
    
    missing
  end
  
  def field_complete?(field)
    case field
    when 'description'
      @school.about.present?
    when 'curricula'
      @school.curricula.any?
    when 'facilities'
      @school.facilities.any?
    when 'grade_offerings'
      @school.school_grade_offering.present?
    when 'contact_info'
      @school.email.present? && @school.display_phone.present?
    when 'extracurriculars'
      @school.extracurriculars.any?
    when 'accreditations'
      @school.accreditations.any?
    when 'photos'
      @place&.photos&.any?
    when 'videos'
      @school.youtube_videos_from_database.any?
    when 'documents'
      @place&.documents&.processing_completed&.any?
    else
      false
    end
  end
  
  # Text processing and relevance calculation
  
  def matches_query?(text, query_terms)
    return false unless text.present?
    
    text_lower = text.downcase
    query_terms.any? { |term| text_lower.include?(term) }
  end
  
  def calculate_text_relevance(text, query_terms)
    return 0.0 unless text.present?
    
    text_lower = text.downcase
    matches = query_terms.count { |term| text_lower.include?(term) }
    
    # Base score on match ratio
    base_score = matches.to_f / query_terms.length
    
    # Bonus for exact phrase matches
    full_query = query_terms.join(' ')
    base_score += 0.3 if text_lower.include?(full_query)
    
    # Bonus for matches at word boundaries
    word_matches = query_terms.count { |term| text_lower.match?(/\b#{Regexp.escape(term)}\b/) }
    base_score += (word_matches.to_f / query_terms.length) * 0.2
    
    [base_score, 1.0].min
  end
  
  def extract_relevant_transcript_excerpt(transcript, query_terms, context_words: 50)
    return transcript.truncate(300) unless transcript.length > 400
    
    # Find first match position
    text_lower = transcript.downcase
    match_position = nil
    
    query_terms.each do |term|
      pos = text_lower.index(term)
      if pos && (match_position.nil? || pos < match_position)
        match_position = pos
      end
    end
    
    return transcript.truncate(300) unless match_position
    
    # Extract context around the match
    words = transcript.split
    word_positions = []
    current_pos = 0
    
    words.each_with_index do |word, index|
      word_positions << [index, current_pos, current_pos + word.length]
      current_pos += word.length + 1
    end
    
    # Find word containing the match
    match_word_index = word_positions.find { |_, start_pos, end_pos| match_position.between?(start_pos, end_pos) }&.first
    return transcript.truncate(300) unless match_word_index
    
    # Extract context
    start_word = [match_word_index - context_words / 2, 0].max
    end_word = [match_word_index + context_words / 2, words.length - 1].min
    
    excerpt = words[start_word..end_word].join(' ')
    excerpt = "...#{excerpt}" if start_word > 0
    excerpt = "#{excerpt}..." if end_word < words.length - 1
    
    excerpt
  end
  
  def build_academic_text
    parts = []
    parts << "Curricula: #{@school.curricula.pluck(:label).join(', ')}" if @school.curricula.any?
    parts << "Accreditations: #{@school.accreditations.pluck(:label).join(', ')}" if @school.accreditations.any?
    parts << "Grade levels: #{@school.grade_levels}" if @school.grade_levels != 'Grades not specified'
    parts << "Age range: #{@school.age_range}" if @school.age_range != 'Ages not specified'
    parts << "Programs: #{@school.programs.pluck(:label).join(', ')}" if @school.programs.any?
    parts.join('. ')
  end
  
  def build_facilities_text
    parts = []
    parts << "Facilities: #{@school.facilities.pluck(:label).join(', ')}" if @school.facilities.any?
    parts << "Boarding available" if @school.boarding?
    parts << "School bus service" if @school.school_bus?
    parts.join('. ')
  end
  
  def build_fee_text
    return '' unless @school.current_fee_schedule
    
    fee_schedule = @school.current_fee_schedule
    parts = []
    parts << "Tuition range: #{fee_schedule.tuition_range_display}" if fee_schedule.respond_to?(:tuition_range_display)
    parts << "Academic year: #{fee_schedule.academic_year}" if fee_schedule.academic_year
    parts.join('. ')
  end
  
  def calculate_detailed_completeness_score
    # More detailed scoring algorithm
    scores = {
      basic_info: calculate_basic_info_score,
      academic_info: calculate_academic_info_score, 
      facilities_info: calculate_facilities_info_score,
      media_content: calculate_media_content_score,
      additional_info: calculate_additional_info_score
    }
    
    weights = {
      basic_info: 0.3,
      academic_info: 0.3,
      facilities_info: 0.2,
      media_content: 0.1,
      additional_info: 0.1
    }
    
    weighted_score = scores.sum { |category, score| score * weights[category] }
    (weighted_score * 100).round
  end
  
  def calculate_basic_info_score
    score = 0.0
    score += 0.25 if @school.about.present?
    score += 0.25 if @school.email.present?
    score += 0.25 if @school.display_phone.present?
    score += 0.25 if @school.display_website.present?
    score
  end
  
  def calculate_academic_info_score
    score = 0.0
    score += 0.4 if @school.curricula.any?
    score += 0.3 if @school.school_grade_offering.present?
    score += 0.2 if @school.programs.any?
    score += 0.1 if @school.accreditations.any?
    score
  end
  
  def calculate_facilities_info_score
    score = 0.0
    score += 0.8 if @school.facilities.any?
    score += 0.1 if @school.boarding?
    score += 0.1 if @school.school_bus?
    score
  end
  
  def calculate_media_content_score
    score = 0.0
    score += 0.4 if @place&.photos&.any?
    score += 0.4 if @school.youtube_videos_from_database.any?
    score += 0.2 if @place&.documents&.processing_completed&.any?
    score
  end
  
  def calculate_additional_info_score
    score = 0.0
    score += 0.3 if @school.extracurriculars.any?
    score += 0.3 if @school.current_fee_schedule.present?
    score += 0.2 if @school.languages.any?
    score += 0.2 if @place&.reviews&.any?
    score
  end
  
  def generate_field_recommendations(missing_required, missing_optional)
    recommendations = []
    
    (missing_required + missing_optional.first(3)).each do |field|
      case field
      when 'description'
        recommendations << {
          field: field,
          priority: 'critical',
          title: 'Add School Description',
          description: 'A compelling description helps parents understand your school\'s mission and values.',
          action_url: '#description-section'
        }
      when 'curricula'
        recommendations << {
          field: field,
          priority: 'critical', 
          title: 'Specify Academic Programs',
          description: 'Parents search by curriculum type. Adding this improves your visibility.',
          action_url: '#academic-programs-section'
        }
      when 'facilities'
        recommendations << {
          field: field,
          priority: 'high',
          title: 'List School Facilities',
          description: 'Showcase your learning environment with a comprehensive facilities list.',
          action_url: '#facilities-section'
        }
      when 'photos'
        recommendations << {
          field: field,
          priority: 'medium',
          title: 'Add Photos',
          description: 'Visual content significantly increases parent engagement.',
          action_url: '#photos-section'
        }
      end
    end
    
    recommendations
  end
  
  def build_completeness_source_references
    [
      {
        type: 'school_data',
        field_name: 'profile_analysis',
        title: 'School Profile Completeness Analysis',
        description: 'Automated analysis of school profile data completeness'
      }
    ]
  end
  
  # Extract relevant excerpt from document content based on query match
  def extract_relevant_document_excerpt(text, query, max_length: 800)
    return text.truncate(max_length) unless text.present? && query.present?
    
    # Normalize query for matching
    query_terms = query.downcase.split(/\s+/)
    text_lower = text.downcase
    
    # Find the position of the best match
    best_match_pos = nil
    best_match_score = 0
    
    # Try to find exact query match first
    exact_pos = text_lower.index(query.downcase)
    if exact_pos
      best_match_pos = exact_pos
      best_match_score = 1.0
    else
      # Look for partial matches with individual terms
      query_terms.each do |term|
        pos = text_lower.index(term)
        if pos
          # Count how many other terms appear nearby
          nearby_text = text_lower[pos, 200] # Check 200 chars around
          nearby_score = query_terms.count { |t| nearby_text.include?(t) }
          
          if nearby_score > best_match_score
            best_match_pos = pos
            best_match_score = nearby_score.to_f / query_terms.length
          end
        end
      end
    end
    
    return text.truncate(max_length) unless best_match_pos
    
    # Extract context around the match
    context_size = max_length / 2
    start_pos = [best_match_pos - context_size, 0].max
    end_pos = [best_match_pos + context_size, text.length].min
    
    excerpt = text[start_pos...end_pos]
    
    # Add ellipsis if we're not at the beginning/end
    excerpt = "...#{excerpt}" if start_pos > 0
    excerpt = "#{excerpt}..." if end_pos < text.length
    
    excerpt
  end
  
  # Calculate relevance score for document matches
  def calculate_document_relevance_score(text, query)
    return 0.5 unless text.present? && query.present?
    
    text_lower = text.downcase
    query_lower = query.downcase
    query_terms = query_lower.split(/\s+/)
    
    score = 0.0
    
    # Exact phrase match gets highest score
    if text_lower.include?(query_lower)
      score += 1.0
    else
      # Partial matches
      matches = query_terms.count { |term| text_lower.include?(term) }
      score += (matches.to_f / query_terms.length) * 0.8
    end
    
    # Bonus for multiple occurrences
    query_terms.each do |term|
      occurrences = text_lower.scan(term).length
      score += (occurrences - 1) * 0.1 if occurrences > 1
    end
    
    # Cap at 1.0
    [score, 1.0].min
  end
end