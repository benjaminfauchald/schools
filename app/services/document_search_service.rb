# Service for searching and retrieving document content for AI integration
# Provides vector similarity search and context generation for chatbot/AI features
class DocumentSearchService
  # Initialize service with optional scope (place or school)
  def initialize(scope = nil)
    @scope = scope
  end
  
  # Search documents by text query
  # Returns documents that contain the search text in their extracted content
  def search_by_text(query, limit: 10)
    return Document.none if query.blank?
    
    documents = base_scope.processing_completed
    documents = documents.search_by_text(query, limit: limit)
    
    {
      query: query,
      results: documents,
      count: documents.count
    }
  end
  
  # Find similar documents using vector similarity search
  # Requires embedding vector (e.g., from OpenAI embeddings API)
  def find_similar_documents(embedding_vector, limit: 5, exclude_ids: [])
    return { results: [], count: 0 } if embedding_vector.blank?
    
    documents = base_scope.find_similar_by_embedding(
      embedding_vector, 
      limit: limit, 
      exclude_ids: exclude_ids
    )
    
    {
      results: documents,
      count: documents.length,
      embedding_dimensions: extract_dimensions(embedding_vector)
    }
  end
  
  # Generate context for AI chatbot from relevant documents
  # Combines document content based on query relevance
  def generate_ai_context(query, max_documents: 5, max_context_length: 4000)
    return generate_empty_context(query) if query.blank?
    
    # First try text search
    text_results = search_by_text(query, limit: max_documents)
    relevant_docs = text_results[:results].to_a
    
    # If we don't have enough results and embeddings are available, try vector search
    if relevant_docs.length < max_documents
      # Note: This would require implementing embedding generation for the query
      # For now, we'll just use text search results
    end
    
    context_parts = []
    current_length = 0
    
    relevant_docs.each do |document|
      next unless document.has_extracted_text?
      
      # Create document context section
      doc_context = format_document_context(document, max_length: 1000)
      
      # Check if adding this document would exceed max length
      if current_length + doc_context.length > max_context_length
        # Try to fit a truncated version
        remaining_space = max_context_length - current_length - 50 # Buffer for truncation indicator
        if remaining_space > 200 # Only add if meaningful content can fit
          truncated_context = doc_context[0...remaining_space] + "...\n\n"
          context_parts << truncated_context
        end
        break
      end
      
      context_parts << doc_context
      current_length += doc_context.length
    end
    
    {
      query: query,
      context: context_parts.join,
      source_documents: relevant_docs.map(&:id),
      document_count: relevant_docs.length,
      context_length: current_length,
      truncated: current_length >= max_context_length
    }
  end
  
  # Get document statistics for AI integration analytics
  def document_statistics
    docs = base_scope
    
    {
      total_documents: docs.count,
      processed_documents: docs.processing_completed.count,
      ai_enabled_documents: docs.ai_enabled.count,
      documents_with_embeddings: docs.with_embeddings.count,
      processing_failed: docs.processing_failed.count,
      pending_processing: docs.pending_processing.count,
      
      # File type breakdown
      file_types: get_file_type_breakdown(docs),
      
      # Processing success rate
      success_rate: calculate_success_rate(docs),
      
      # Average processing time (if trackable)
      total_extracted_text_length: get_total_text_length(docs)
    }
  end
  
  # Export document content for external AI services
  # Returns formatted document content suitable for AI training or analysis
  def export_for_ai(format: :json, include_metadata: true)
    documents = base_scope.processing_completed.ai_enabled
    
    case format
    when :json
      export_as_json(documents, include_metadata: include_metadata)
    when :text
      export_as_text(documents, include_metadata: include_metadata)
    when :csv
      export_as_csv(documents, include_metadata: include_metadata)
    else
      raise ArgumentError, "Unsupported export format: #{format}"
    end
  end
  
  # Find documents that might need reprocessing
  # Useful for maintenance and quality assurance
  def find_documents_needing_attention
    docs = base_scope
    
    {
      failed_processing: docs.processing_failed,
      no_extracted_text: docs.processing_completed.where(extracted_text: [nil, '']),
      ai_enabled_without_embeddings: docs.ai_enabled.processing_completed.where(embedding: nil),
      large_documents: docs.where('file_size > ?', 50.megabytes),
      old_documents: docs.where('created_at < ? AND last_processed_at IS NULL', 30.days.ago)
    }
  end
  
  private
  
  def base_scope
    return @scope.documents if @scope.respond_to?(:documents)
    return Document.where(place: @scope) if @scope.is_a?(Place)
    return @scope if @scope.respond_to?(:where)
    Document.all
  end
  
  def generate_empty_context(query)
    {
      query: query,
      context: "",
      source_documents: [],
      document_count: 0,
      context_length: 0,
      truncated: false
    }
  end
  
  def format_document_context(document, max_length: 1000)
    context = []
    
    # Document header
    context << "Document: #{document.filename}"
    context << "Type: #{document.file_type_display}"
    context << "Uploaded: #{document.created_at.strftime('%Y-%m-%d')}"
    context << ""
    
    # Document content
    if document.has_extracted_text?
      text = document.extracted_text.strip
      if text.length > max_length
        text = text[0...max_length] + "..."
      end
      context << text
    else
      context << "[No text content extracted]"
    end
    
    context << ""
    context << "---"
    context << ""
    
    context.join("\n")
  end
  
  def get_file_type_breakdown(documents)
    breakdown = {}
    
    documents.group_by(&:file_extension).each do |extension, docs|
      extension_name = extension&.upcase&.gsub('.', '') || 'Unknown'
      breakdown[extension_name] = {
        count: docs.length,
        total_size: docs.sum(&:file_size),
        processed: docs.count(&:processing_completed?),
        ai_enabled: docs.count(&:ai_enabled?)
      }
    end
    
    breakdown
  end
  
  def calculate_success_rate(documents)
    total = documents.count
    return 0.0 if total == 0
    
    successful = documents.processing_completed.count
    (successful.to_f / total * 100).round(1)
  end
  
  def get_total_text_length(documents)
    documents.processing_completed
             .where.not(extracted_text: [nil, ''])
             .sum { |doc| doc.extracted_text&.length || 0 }
  end
  
  def extract_dimensions(embedding_vector)
    return nil if embedding_vector.blank?
    
    # Handle different embedding vector formats
    case embedding_vector
    when String
      # Assume PostgreSQL vector format: "[1,2,3,...]"
      embedding_vector.scan(/,/).length + 1
    when Array
      embedding_vector.length
    else
      nil
    end
  end
  
  def export_as_json(documents, include_metadata:)
    {
      export_date: Time.current.iso8601,
      document_count: documents.count,
      documents: documents.map do |doc|
        data = {
          id: doc.id,
          filename: doc.filename,
          file_type: doc.file_type_display,
          extracted_text: doc.extracted_text,
          created_at: doc.created_at.iso8601,
          processed_at: doc.last_processed_at&.iso8601
        }
        
        if include_metadata
          data.merge!(
            file_size: doc.file_size,
            download_count: doc.download_count,
            ai_enabled: doc.ai_enabled?,
            has_embedding: doc.has_embedding?,
            metadata: doc.metadata
          )
        end
        
        data
      end
    }
  end
  
  def export_as_text(documents, include_metadata:)
    content = ["Document Export - #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}", ""]
    content << "Total Documents: #{documents.count}"
    content << ""
    content << "=" * 50
    content << ""
    
    documents.each_with_index do |doc, index|
      content << "Document ##{index + 1}: #{doc.filename}"
      content << "Type: #{doc.file_type_display}"
      content << "Created: #{doc.created_at.strftime('%Y-%m-%d %H:%M:%S')}"
      
      if include_metadata
        content << "Size: #{doc.file_size} bytes"
        content << "Downloads: #{doc.download_count}"
        content << "AI Enabled: #{doc.ai_enabled? ? 'Yes' : 'No'}"
      end
      
      content << ""
      content << "Content:"
      content << "-" * 20
      content << doc.extracted_text.presence || "[No text content]"
      content << ""
      content << "=" * 50
      content << ""
    end
    
    content.join("\n")
  end
  
  def export_as_csv(documents, include_metadata:)
    require 'csv'
    
    headers = ['ID', 'Filename', 'File Type', 'Extracted Text', 'Created At', 'Processed At']
    
    if include_metadata
      headers.concat(['File Size', 'Download Count', 'AI Enabled', 'Has Embedding'])
    end
    
    CSV.generate do |csv|
      csv << headers
      
      documents.each do |doc|
        row = [
          doc.id,
          doc.filename,
          doc.file_type_display,
          doc.extracted_text,
          doc.created_at.iso8601,
          doc.last_processed_at&.iso8601
        ]
        
        if include_metadata
          row.concat([
            doc.file_size,
            doc.download_count,
            doc.ai_enabled?,
            doc.has_embedding?
          ])
        end
        
        csv << row
      end
    end
  end
end