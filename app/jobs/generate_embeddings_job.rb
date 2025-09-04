# Background job for batch processing transcript embeddings
# Processes multiple transcripts missing embeddings in the background
class GenerateEmbeddingsJob < ApplicationJob
  queue_as :default
  
  # Retry configuration with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  retry_on Timeout::Error, wait: 1.minute, attempts: 5
  
  # Discard job on configuration errors
  discard_on ArgumentError
  
  def perform(options = {})
    limit = options.fetch('limit', 10)
    school_id = options['school_id']
    content_type = options.fetch('content_type', 'all').to_sym  # :all, :transcripts, :documents
    
    Rails.logger.info "🚀 GenerateEmbeddingsJob started with limit: #{limit}, school_id: #{school_id}, content_type: #{content_type}"
    
    begin
      embedding_service = EmbeddingGenerationService.new
      
      # Process specific school or all schools
      if school_id
        Rails.logger.info "🏫 Processing #{content_type} embeddings for school #{school_id}"
        results = process_school_content(embedding_service, school_id, limit, content_type)
      else
        Rails.logger.info "🌐 Processing #{content_type} embeddings across all schools"
        results = embedding_service.batch_process_missing_embeddings(limit: limit, content_type: content_type)
      end
      
      Rails.logger.info "✅ GenerateEmbeddingsJob completed successfully"
      Rails.logger.info "📊 Results: #{results[:processed]} processed, #{results[:failed]} failed"
      Rails.logger.info "📊 Segments: #{results[:total_segments_processed]} processed, #{results[:total_segments_failed]} failed"
      
      # Optional: Broadcast completion status for real-time updates
      if school_id
        broadcast_completion_status(school_id, results)
      end
      
      results
      
    rescue => e
      Rails.logger.error "💥 GenerateEmbeddingsJob failed: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      
      # Re-raise to trigger retry logic
      raise e
    end
  end
  
  private
  
  def process_school_content(embedding_service, school_id, limit, content_type)
    school = School.find(school_id)
    place = school.place
    
    unless place
      Rails.logger.warn "⚠️ School #{school_id} has no associated place"
      return { processed: 0, failed: 0, skipped: 1, total_segments_processed: 0, total_segments_failed: 0 }
    end
    
    results = {
      processed: 0,
      failed: 0,
      skipped: 0,
      total_segments_processed: 0,
      total_segments_failed: 0
    }
    
    # Process transcripts if requested
    if content_type == :all || content_type == :transcripts
      Rails.logger.info "📹 Processing transcripts for school #{school.name}"
      transcript_results = process_school_transcripts(embedding_service, place, limit)
      
      results[:processed] += transcript_results[:processed]
      results[:failed] += transcript_results[:failed]
      results[:total_segments_processed] += transcript_results[:total_segments_processed]
      results[:total_segments_failed] += transcript_results[:total_segments_failed]
    end
    
    # Process documents if requested
    if content_type == :all || content_type == :documents
      Rails.logger.info "📄 Processing documents for school #{school.name}"
      document_results = process_school_documents(embedding_service, place, limit)
      
      results[:processed] += document_results[:processed]
      results[:failed] += document_results[:failed]
    end
    
    results
  end
  
  def process_school_transcripts(embedding_service, place, limit)
    # Find transcripts for this specific place that need embeddings
    transcripts_needing_embeddings = place.transcripts
                                          .processed
                                          .ai_enabled
                                          .where(vector_embedding: nil)
                                          .or(place.transcripts.processed.ai_enabled.where(embedding_generated_at: nil))
                                          .limit(limit)
    
    Rails.logger.info "📋 Found #{transcripts_needing_embeddings.count} transcripts needing embeddings"
    
    results = {
      processed: 0,
      failed: 0,
      total_segments_processed: 0,
      total_segments_failed: 0
    }
    
    transcripts_needing_embeddings.find_each do |transcript|
      Rails.logger.info "🔄 Processing transcript #{transcript.id}"
      
      result = embedding_service.process_transcript(transcript)
      
      if result[:success]
        results[:processed] += 1
        results[:total_segments_processed] += result[:segments_processed]
        results[:total_segments_failed] += result[:segments_failed]
      else
        results[:failed] += 1
        Rails.logger.error "❌ Failed to process transcript #{transcript.id}: #{result[:error]}"
      end
      
      # Rate limiting between transcripts
      sleep(0.5)
    end
    
    results
  end
  
  def process_school_documents(embedding_service, place, limit)
    # Find documents for this specific place that need embeddings
    documents_needing_embeddings = place.documents
                                       .processing_completed
                                       .ai_enabled
                                       .where(embedding: nil)
                                       .where.not(extracted_text: [nil, ''])
                                       .limit(limit)
    
    Rails.logger.info "📋 Found #{documents_needing_embeddings.count} documents needing embeddings"
    
    results = {
      processed: 0,
      failed: 0
    }
    
    documents_needing_embeddings.find_each do |document|
      Rails.logger.info "🔄 Processing document #{document.id} - #{document.filename}"
      
      result = embedding_service.process_document(document)
      
      if result[:success]
        results[:processed] += 1
      else
        results[:failed] += 1
        Rails.logger.error "❌ Failed to process document #{document.id}: #{result[:error]}"
      end
      
      # Rate limiting between documents
      sleep(0.5)
    end
    
    results
  end
  
  def broadcast_completion_status(school_id, results)
    # Broadcast to school owner dashboard for real-time updates
    Turbo::StreamsChannel.broadcast_replace_to(
      "school_#{school_id}_embedding_status",
      target: "embedding_status",
      html: ApplicationController.render(
        partial: 'school_owner/schools/embedding_status',
        locals: { 
          status: 'completed',
          results: results
        }
      )
    )
  rescue => e
    Rails.logger.warn "⚠️ Failed to broadcast embedding status: #{e.message}"
  end
end