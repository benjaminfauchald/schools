class GenerateEmbeddingJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  def perform(record)
    Rails.logger.info "Generating embedding for #{record.class.name} #{record.id}"
    
    text = extract_text_for_embedding(record)
    
    if text.blank?
      Rails.logger.warn "No text found for embedding generation: #{record.class.name} #{record.id}"
      return
    end
    
    # Log text length for monitoring
    Rails.logger.info "Text length: #{text.length} characters, estimated tokens: #{EmbeddingService.estimate_tokens(text)}"
    
    # Check if text needs chunking
    if EmbeddingService.exceeds_token_limit?(text)
      Rails.logger.info "Text exceeds token limit, chunking for #{record.class.name} #{record.id}"
      generate_chunked_embeddings(record, text)
    else
      generate_single_embedding(record, text)
    end
  end
  
  private
  
  def extract_text_for_embedding(record)
    case record
    when Transcript
      record.full_transcript_text
    when TranscriptSegment
      record.text
    when DocumentContent
      record.processed_text
    else
      # Fallback for other models
      record.try(:content) || record.try(:text) || record.try(:body)
    end
  end
  
  def generate_single_embedding(record, text)
    embedding = EmbeddingService.generate_embedding(text)
    
    if embedding
      record.update_column(:embedding, embedding)
      Rails.logger.info "Successfully generated embedding for #{record.class.name} #{record.id}"
      
      # Update processing status if it's a DocumentContent
      if record.is_a?(DocumentContent) && record.pending?
        record.mark_as_completed!
      end
    else
      Rails.logger.error "Failed to generate embedding for #{record.class.name} #{record.id}"
      
      # Mark as failed if it's a DocumentContent
      if record.is_a?(DocumentContent) 
        record.mark_as_failed!("Failed to generate embedding")
      end
      
      raise "Failed to generate embedding"
    end
  end
  
  def generate_chunked_embeddings(record, text)
    chunks = EmbeddingService.chunk_text(text, 1000, 100)
    Rails.logger.info "Generated #{chunks.length} chunks for #{record.class.name} #{record.id}"
    
    # For chunked content, we'll generate embeddings for each chunk
    # and store them as separate DocumentContent records
    if record.is_a?(DocumentContent)
      generate_chunked_document_embeddings(record, chunks)
    else
      # For transcripts and segments, use the first chunk as the main embedding
      main_embedding = EmbeddingService.generate_embedding(chunks.first)
      
      if main_embedding
        record.update_column(:embedding, main_embedding)
        Rails.logger.info "Successfully generated embedding from first chunk for #{record.class.name} #{record.id}"
      else
        Rails.logger.error "Failed to generate embedding from chunks for #{record.class.name} #{record.id}"
        raise "Failed to generate embedding from chunks"
      end
    end
  end
  
  def generate_chunked_document_embeddings(original_document, chunks)
    transaction do
      # Generate embeddings for all chunks
      embeddings = EmbeddingService.generate_embeddings(chunks)
      
      if embeddings.length == chunks.length
        # Create separate DocumentContent records for each chunk
        chunks.each_with_index do |chunk, index|
          next if index == 0 # Skip first chunk, use original document
          
          chunk_document = DocumentContent.create!(
            place: original_document.place,
            title: "#{original_document.title} (Part #{index + 1})",
            content_type: original_document.content_type,
            processed_text: chunk,
            embedding: embeddings[index],
            processing_status: 'completed',
            metadata: (original_document.metadata || {}).merge(
              chunk_index: index + 1,
              total_chunks: chunks.length,
              parent_document_id: original_document.id,
              created_from_chunking: true
            )
          )
          
          Rails.logger.info "Created chunk document #{chunk_document.id} for parent #{original_document.id}"
        end
        
        # Update original document with first chunk's embedding
        original_document.update!(
          embedding: embeddings.first,
          processed_text: chunks.first,
          metadata: (original_document.metadata || {}).merge(
            chunk_index: 1,
            total_chunks: chunks.length,
            has_chunks: true
          )
        )
        original_document.mark_as_completed!
        
        Rails.logger.info "Successfully generated #{embeddings.length} chunk embeddings for DocumentContent #{original_document.id}"
      else
        Rails.logger.error "Mismatch between chunks (#{chunks.length}) and embeddings (#{embeddings.length}) for DocumentContent #{original_document.id}"
        original_document.mark_as_failed!("Chunk embedding generation failed")
        raise "Chunk embedding generation failed"
      end
    end
  end
  
  def transaction(&block)
    ActiveRecord::Base.transaction(&block)
  end
end