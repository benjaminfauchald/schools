# Transcript processing and cleaning rake tasks
# Handles transcript cleaning and embedding generation workflow

namespace :transcripts do
  desc "Clean transcripts using AI to remove audio cues and improve quality"
  task clean_transcripts: :environment do
    puts "🧹 Starting transcript cleaning process..."
    
    # Get options from environment
    limit = ENV['LIMIT']&.to_i || 10
    
    puts "📋 Processing up to #{limit} transcripts for cleaning"
    
    begin
      service = TranscriptCleaningService.new
      results = service.batch_clean_transcripts(limit: limit)
      
      puts "\n✅ Transcript cleaning completed!"
      puts "📊 Results:"
      puts "  - Processed: #{results[:processed]}"
      puts "  - Failed: #{results[:failed]}"
      puts "  - Skipped: #{results[:skipped]}"
      
      if results[:total_original_chars] > 0
        puts "  - Original characters: #{number_with_delimiter(results[:total_original_chars])}"
        puts "  - Cleaned characters: #{number_with_delimiter(results[:total_cleaned_chars])}"
        puts "  - Quality improvement: #{results[:improvement_percentage]}%"
      end
      
    rescue => e
      puts "❌ Error during transcript cleaning: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit(1)
    end
  end

  desc "Generate embeddings for cleaned transcripts"
  task generate_embeddings: :environment do
    puts "🚀 Starting embedding generation for cleaned transcripts..."
    
    limit = ENV['LIMIT']&.to_i || 10
    puts "📋 Processing up to #{limit} transcripts for embedding generation"
    
    begin
      service = EmbeddingGenerationService.new
      
      # Find transcripts with cleaned content that need embeddings
      transcripts_ready = Transcript.processed
                                   .ai_enabled
                                   .cleaned
                                   .where(vector_embedding: nil)
                                   .limit(limit)
      
      puts "📋 Found #{transcripts_ready.count} cleaned transcripts ready for embeddings"
      
      results = {
        processed: 0,
        failed: 0,
        from_cleaned: 0,
        from_raw: 0
      }
      
      transcripts_ready.find_each do |transcript|
        puts "🔄 Processing transcript #{transcript.id} - #{transcript.video_title || transcript.video_id}"
        
        result = service.process_transcript(transcript)
        
        if result[:success]
          results[:processed] += 1
          if result[:content_type] == 'cleaned'
            results[:from_cleaned] += 1
          else
            results[:from_raw] += 1
          end
          puts "  ✅ Generated embedding (#{result[:content_type]} content, #{result[:content_length]} chars)"
        else
          results[:failed] += 1
          puts "  ❌ Failed: #{result[:error]}"
        end
        
        # Rate limiting between API calls
        sleep(1)
      end
      
      puts "\n✅ Embedding generation completed!"
      puts "📊 Results:"
      puts "  - Processed: #{results[:processed]}"
      puts "  - Failed: #{results[:failed]}"
      puts "  - From cleaned content: #{results[:from_cleaned]}"
      puts "  - From raw content: #{results[:from_raw]}"
      
    rescue => e
      puts "❌ Error during embedding generation: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit(1)
    end
  end

  desc "Full workflow: clean transcripts and generate embeddings"
  task process_all: :environment do
    puts "🔄 Running full transcript processing workflow..."
    
    limit = ENV['LIMIT']&.to_i || 5
    puts "📋 Processing up to #{limit} transcripts"
    
    # Step 1: Clean transcripts
    puts "\n🧹 Step 1: Cleaning transcripts..."
    ENV['LIMIT'] = limit.to_s  # Ensure LIMIT is passed to subtasks
    Rake::Task['transcripts:clean_transcripts'].invoke
    
    # Step 2: Generate embeddings for cleaned transcripts
    puts "\n🚀 Step 2: Generating embeddings..."
    ENV['LIMIT'] = limit.to_s  # Ensure LIMIT is passed to subtasks
    Rake::Task['transcripts:generate_embeddings'].invoke
    
    puts "\n✅ Full transcript processing workflow completed!"
  end

  desc "Compare transcript quality (show before/after examples)"
  task compare_quality: :environment do
    puts "📊 Transcript Quality Comparison\n"
    
    # Find transcripts with both raw and cleaned versions
    comparison_transcripts = Transcript.cleaned
                                      .where.not(full_transcript: [nil, ''])
                                      .limit(3)
    
    if comparison_transcripts.empty?
      puts "❌ No transcripts with cleaned versions found"
      puts "Run: bin/rails transcripts:clean_transcripts first"
      exit
    end
    
    comparison_transcripts.each_with_index do |transcript, i|
      puts "#{i + 1}. #{transcript.video_title || transcript.video_id}"
      puts "   Cleaned at: #{transcript.transcript_cleaned_at&.strftime('%Y-%m-%d %H:%M')}"
      puts ""
      
      puts "📄 ORIGINAL (#{transcript.full_transcript.length} chars):"
      puts transcript.full_transcript.truncate(300)
      puts ""
      
      puts "✨ CLEANED (#{transcript.cleaned_transcript.length} chars):"
      puts transcript.cleaned_transcript.truncate(300)
      puts ""
      
      # Calculate improvement metrics
      original_length = transcript.full_transcript.length
      cleaned_length = transcript.cleaned_transcript.length
      improvement = ((cleaned_length.to_f / original_length) * 100).round(1)
      
      puts "📈 Improvement: #{improvement}% length efficiency"
      puts "=" * 80
      puts ""
    end
  end

  desc "Show transcript processing statistics"
  task stats: :environment do
    puts "📊 Transcript Processing Statistics\n"
    
    # Overall transcript counts
    total_transcripts = Transcript.count
    processed_transcripts = Transcript.processed.count
    ai_enabled_transcripts = Transcript.processed.ai_enabled.count
    
    puts "📹 Overall Transcripts:"
    puts "  Total transcripts: #{total_transcripts}"
    puts "  Processed transcripts: #{processed_transcripts}"
    puts "  AI-enabled transcripts: #{ai_enabled_transcripts}"
    
    # Cleaning statistics
    cleaned_transcripts = Transcript.cleaned.count
    needs_cleaning = Transcript.needs_cleaning.count
    
    puts "\n🧹 Cleaning Status:"
    puts "  Cleaned transcripts: #{cleaned_transcripts}"
    puts "  Needs cleaning: #{needs_cleaning}"
    
    if ai_enabled_transcripts > 0
      cleaning_percentage = (cleaned_transcripts.to_f / ai_enabled_transcripts * 100).round(1)
      puts "  Cleaning coverage: #{cleaning_percentage}%"
    end
    
    # Embedding statistics  
    transcripts_with_embeddings = Transcript.with_embeddings.count
    cleaned_with_embeddings = Transcript.cleaned.with_embeddings.count
    ready_for_embeddings = Transcript.cleaned.where(vector_embedding: nil).count
    
    puts "\n🔮 Embedding Status:"
    puts "  Transcripts with embeddings: #{transcripts_with_embeddings}"
    puts "  Cleaned transcripts with embeddings: #{cleaned_with_embeddings}"
    puts "  Cleaned transcripts ready for embeddings: #{ready_for_embeddings}"
    
    if cleaned_transcripts > 0
      embedding_percentage = (cleaned_with_embeddings.to_f / cleaned_transcripts * 100).round(1)
      puts "  Embedding coverage (cleaned): #{embedding_percentage}%"
    end
    
    # Recent activity
    recent_cutoff = 7.days.ago
    recent_cleanings = Transcript.where('transcript_cleaned_at > ?', recent_cutoff).count
    recent_embeddings = Transcript.where('embedding_generated_at > ?', recent_cutoff).count
    
    puts "\n📈 Recent Activity (last 7 days):"
    puts "  Recent cleanings: #{recent_cleanings}"
    puts "  Recent embeddings: #{recent_embeddings}"
    
    # Recommendations
    puts "\n💡 Next Steps:"
    if needs_cleaning > 0
      puts "  - Run: bin/rails transcripts:clean_transcripts LIMIT=#{[needs_cleaning, 5].min}"
    end
    if ready_for_embeddings > 0
      puts "  - Run: bin/rails transcripts:generate_embeddings LIMIT=#{[ready_for_embeddings, 5].min}"
    end
    if needs_cleaning == 0 && ready_for_embeddings == 0
      puts "  ✅ All AI-enabled transcripts are processed and ready!"
    end
  end

  desc "Cleanup segment embeddings (no longer used)"
  task cleanup_segment_embeddings: :environment do
    puts "🧹 Cleaning up unused transcript segment embeddings..."
    
    # Count existing segment embeddings
    segments_with_embeddings = TranscriptSegment.where.not(vector_embedding: nil).count
    
    puts "📋 Found #{segments_with_embeddings} transcript segments with embeddings"
    
    if segments_with_embeddings == 0
      puts "✅ No segment embeddings to clean up"
      return
    end
    
    # Confirm cleanup
    print "⚠️  This will remove all segment-level embeddings (we now use full transcript embeddings only).\n"
    print "Continue? (y/N): "
    
    response = STDIN.gets.chomp.downcase
    unless response == 'y' || response == 'yes'
      puts "❌ Cleanup cancelled"
      return
    end
    
    # Clear segment embeddings
    updated_count = TranscriptSegment.where.not(vector_embedding: nil).update_all(
      vector_embedding: nil,
      embedding_generated_at: nil
    )
    
    puts "✅ Cleaned up #{updated_count} segment embeddings"
    puts "💾 Segments are still available for text search and timestamps"
    puts "🔍 Vector search now uses full transcript embeddings for better context"
  end

  private

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end