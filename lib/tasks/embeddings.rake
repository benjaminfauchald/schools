# Unified embedding management rake tasks
# Handles both transcript and document embeddings using the EmbeddingGenerationService

namespace :embeddings do
  desc "Generate embeddings for all content missing embeddings"
  task generate_missing: :environment do
    puts "🚀 Starting embedding generation for all content..."
    
    # Get options from environment
    limit = ENV['LIMIT']&.to_i || 50
    content_type = (ENV['TYPE'] || 'all').to_sym  # all, transcripts, documents
    
    puts "📋 Processing up to #{limit} items of type: #{content_type}"
    
    begin
      service = EmbeddingGenerationService.new
      results = service.batch_process_missing_embeddings(limit: limit, content_type: content_type)
      
      puts "\n✅ Embedding generation completed!"
      puts "📊 Overall Results:"
      puts "  - Processed: #{results[:processed]}"
      puts "  - Failed: #{results[:failed]}"
      puts "  - Skipped: #{results[:skipped]}"
      
      if results[:total_segments_processed]
        puts "  - Transcript segments processed: #{results[:total_segments_processed]}"
        puts "  - Transcript segments failed: #{results[:total_segments_failed]}"
      end
      
      # Show breakdown by content type
      results[:content_types]&.each do |type, type_results|
        puts "\n📋 #{type.to_s.humanize} Results:"
        puts "  - Processed: #{type_results[:processed]}"
        puts "  - Failed: #{type_results[:failed]}"
        
        if type_results[:total_segments_processed]
          puts "  - Segments processed: #{type_results[:total_segments_processed]}"
          puts "  - Segments failed: #{type_results[:total_segments_failed]}"
        end
      end
      
    rescue => e
      puts "❌ Error during embedding generation: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit(1)
    end
  end

  desc "Generate embeddings for specific school"  
  task generate_for_school: :environment do
    school_id = ENV['SCHOOL_ID']
    
    unless school_id
      puts "❌ Please provide SCHOOL_ID environment variable"
      puts "Usage: SCHOOL_ID=123 bin/rails embeddings:generate_for_school"
      exit(1)
    end
    
    begin
      school = School.find(school_id)
      puts "🏫 Generating embeddings for school: #{school.name} (ID: #{school_id})"
      
      limit = ENV['LIMIT']&.to_i || 20
      content_type = (ENV['TYPE'] || 'all').to_sym
      
      # Queue the job instead of processing directly for better reliability
      job = GenerateEmbeddingsJob.perform_later({
        'school_id' => school_id,
        'limit' => limit,
        'content_type' => content_type.to_s
      })
      
      puts "📤 Queued embedding generation job: #{job.job_id}"
      puts "📋 Processing up to #{limit} items of type: #{content_type}"
      puts "⏳ Check job status in the background job system"
      
    rescue ActiveRecord::RecordNotFound
      puts "❌ School with ID #{school_id} not found"
      exit(1)
    rescue => e
      puts "❌ Error queuing embedding generation: #{e.message}"
      exit(1)
    end
  end

  desc "Regenerate old embeddings"
  task regenerate_old: :environment do
    days_old = ENV['DAYS']&.to_i || 30
    limit = ENV['LIMIT']&.to_i || 20
    content_type = (ENV['TYPE'] || 'all').to_sym
    
    puts "🔄 Regenerating embeddings older than #{days_old} days..."
    puts "📋 Processing up to #{limit} items of type: #{content_type}"
    
    cutoff_date = days_old.days.ago
    
    begin
      service = EmbeddingGenerationService.new
      
      processed = 0
      failed = 0
      
      # Process old transcript embeddings
      if content_type == :all || content_type == :transcripts
        puts "📹 Finding old transcript embeddings..."
        old_transcripts = Transcript.processed
                                   .ai_enabled
                                   .where('embedding_generated_at < ?', cutoff_date)
                                   .limit(limit)
        
        puts "📋 Found #{old_transcripts.count} old transcript embeddings to regenerate"
        
        old_transcripts.find_each do |transcript|
          puts "🔄 Regenerating transcript #{transcript.id} embedding..."
          result = service.process_transcript(transcript)
          
          if result[:success]
            processed += 1
            puts "  ✅ Regenerated"
          else
            failed += 1
            puts "  ❌ Failed: #{result[:error]}"
          end
          
          sleep(0.5) # Rate limiting
        end
      end
      
      # Process old document embeddings  
      if content_type == :all || content_type == :documents
        puts "📄 Finding old document embeddings..."
        old_documents = Document.processing_completed
                               .ai_enabled
                               .where('last_processed_at < ?', cutoff_date)
                               .where.not(embedding: nil)
                               .limit(limit)
        
        puts "📋 Found #{old_documents.count} old document embeddings to regenerate"
        
        old_documents.find_each do |document|
          puts "🔄 Regenerating document #{document.id} embedding..."
          result = service.process_document(document)
          
          if result[:success]
            processed += 1
            puts "  ✅ Regenerated"
          else
            failed += 1
            puts "  ❌ Failed: #{result[:error]}"
          end
          
          sleep(0.5) # Rate limiting
        end
      end
      
      puts "\n✅ Regeneration completed!"
      puts "📊 Results: #{processed} processed, #{failed} failed"
      
    rescue => e
      puts "❌ Error during regeneration: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit(1)
    end
  end

  desc "Show embedding statistics"
  task stats: :environment do
    puts "📊 Embedding Statistics\n"
    
    # Transcript statistics
    puts "📹 Transcripts:"
    total_transcripts = Transcript.count
    processed_transcripts = Transcript.processed.count
    ai_enabled_transcripts = Transcript.processed.ai_enabled.count
    transcripts_with_embeddings = Transcript.processed.ai_enabled.where.not(vector_embedding: nil).count
    
    puts "  Total transcripts: #{total_transcripts}"
    puts "  Processed transcripts: #{processed_transcripts}"  
    puts "  AI-enabled transcripts: #{ai_enabled_transcripts}"
    puts "  With embeddings: #{transcripts_with_embeddings}"
    
    if ai_enabled_transcripts > 0
      embedding_percentage = (transcripts_with_embeddings.to_f / ai_enabled_transcripts * 100).round(1)
      puts "  Embedding coverage: #{embedding_percentage}%"
    end
    
    # Transcript segments statistics
    puts "\n📝 Transcript Segments:"
    total_segments = TranscriptSegment.count
    segments_with_embeddings = TranscriptSegment.where.not(vector_embedding: nil).count
    
    puts "  Total segments: #{total_segments}"
    puts "  With embeddings: #{segments_with_embeddings}"
    
    if total_segments > 0
      segment_embedding_percentage = (segments_with_embeddings.to_f / total_segments * 100).round(1)
      puts "  Embedding coverage: #{segment_embedding_percentage}%"
    end
    
    # Document statistics
    puts "\n📄 Documents:"
    total_documents = Document.count
    processed_documents = Document.processing_completed.count
    ai_enabled_documents = Document.processing_completed.ai_enabled.count
    documents_with_embeddings = Document.processing_completed.ai_enabled.where.not(embedding: nil).count
    
    puts "  Total documents: #{total_documents}"
    puts "  Processed documents: #{processed_documents}"
    puts "  AI-enabled documents: #{ai_enabled_documents}"
    puts "  With embeddings: #{documents_with_embeddings}"
    
    if ai_enabled_documents > 0
      doc_embedding_percentage = (documents_with_embeddings.to_f / ai_enabled_documents * 100).round(1)
      puts "  Embedding coverage: #{doc_embedding_percentage}%"
    end
    
    # Missing embeddings summary
    puts "\n⚠️  Missing Embeddings:"
    missing_transcript_embeddings = ai_enabled_transcripts - transcripts_with_embeddings
    missing_document_embeddings = ai_enabled_documents - documents_with_embeddings
    
    puts "  Transcripts needing embeddings: #{missing_transcript_embeddings}"
    puts "  Documents needing embeddings: #{missing_document_embeddings}"
    
    # Recent embedding activity
    puts "\n📈 Recent Activity (last 7 days):"
    recent_cutoff = 7.days.ago
    
    recent_transcript_embeddings = Transcript.where('embedding_generated_at > ?', recent_cutoff).count
    recent_document_embeddings = Document.where('last_processed_at > ?', recent_cutoff)
                                         .where.not(embedding: nil).count
    
    puts "  Recent transcript embeddings: #{recent_transcript_embeddings}"
    puts "  Recent document embeddings: #{recent_document_embeddings}"
    
    if missing_transcript_embeddings > 0 || missing_document_embeddings > 0
      puts "\n💡 Suggestions:"
      puts "  Run: bin/rails embeddings:generate_missing LIMIT=10"
      puts "  Or for specific type: bin/rails embeddings:generate_missing TYPE=transcripts LIMIT=5"
    else
      puts "\n✅ All AI-enabled content has embeddings!"
    end
  end

  desc "Clean up orphaned or invalid embeddings"
  task cleanup: :environment do
    puts "🧹 Cleaning up embeddings..."
    
    cleaned_transcripts = 0
    cleaned_segments = 0
    cleaned_documents = 0
    
    # Clean transcript embeddings that don't have generated_at timestamps
    puts "📹 Cleaning transcript embeddings without timestamps..."
    transcripts_without_timestamp = Transcript.where.not(vector_embedding: nil)
                                             .where(embedding_generated_at: nil)
    
    transcripts_without_timestamp.find_each do |transcript|
      puts "  🔧 Fixing timestamp for transcript #{transcript.id}"
      transcript.update!(embedding_generated_at: transcript.updated_at)
      cleaned_transcripts += 1
    end
    
    # Clean segment embeddings that don't have generated_at timestamps
    puts "📝 Cleaning segment embeddings without timestamps..."
    segments_without_timestamp = TranscriptSegment.where.not(vector_embedding: nil)
                                                 .where(embedding_generated_at: nil)
    
    segments_without_timestamp.find_each do |segment|
      puts "  🔧 Fixing timestamp for segment #{segment.id}"
      segment.update!(embedding_generated_at: segment.updated_at)
      cleaned_segments += 1
    end
    
    # Clean documents with embeddings but no processing timestamp
    puts "📄 Cleaning document embeddings without timestamps..."
    documents_without_timestamp = Document.where.not(embedding: nil)
                                         .where(last_processed_at: nil)
    
    documents_without_timestamp.find_each do |document|
      puts "  🔧 Fixing timestamp for document #{document.id}"
      document.update!(last_processed_at: document.updated_at)
      cleaned_documents += 1
    end
    
    puts "\n✅ Cleanup completed!"
    puts "📊 Results:"
    puts "  Transcripts cleaned: #{cleaned_transcripts}"
    puts "  Segments cleaned: #{cleaned_segments}"
    puts "  Documents cleaned: #{cleaned_documents}"
  end
end