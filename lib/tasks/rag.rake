namespace :rag do
  desc "Test RAG system with a simple question"
  task :test, [:place_id, :question] => :environment do |t, args|
    place_id = args[:place_id]&.to_i || 271
    question = args[:question] || "What is this school's teaching philosophy?"
    
    puts "🔍 RAG Test Query"
    puts "=" * 50
    puts "Place ID: #{place_id}"
    puts "Question: #{question}"
    puts "=" * 50
    
    result = SimpleRagService.ask_question(place_id, question)
    
    if result[:success]
      puts "✅ SUCCESS"
      puts "\n📝 Answer:"
      puts result[:answer]
      
      puts "\n📚 Sources (#{result[:context_stats][:sources_found]}):"
      result[:sources].each_with_index do |source, i|
        puts "  #{i + 1}. #{source[:title]}"
        puts "     Type: #{source[:type]}, Relevance: #{source[:relevance_score]}"
      end
      
      puts "\n📊 Usage Stats:"
      puts "  Context tokens: #{result[:context_stats][:tokens_used]}"
      puts "  AI tokens: #{result[:ai_usage]['total_tokens'] || 'N/A'}"
      
    else
      puts "❌ FAILED"
      puts "Error: #{result[:error]}"
    end
  end
  
  desc "Check available content for RAG"
  task :check_content, [:place_id] => :environment do |t, args|
    place_id = args[:place_id]&.to_i || 271
    
    puts "📊 RAG Content Check for Place #{place_id}"
    puts "=" * 50
    
    # Check transcripts
    transcripts = Transcript.for_place(place_id).processed
    puts "🎥 Transcripts: #{transcripts.count}"
    
    if transcripts.any?
      puts "   With embeddings: #{transcripts.with_embeddings.count}"
      puts "   Recent videos:"
      transcripts.order(created_at: :desc).limit(3).each do |t|
        status = t.embedding.present? ? "✅" : "❌"
        puts "   #{status} #{t.video_title} (#{t.created_at.strftime('%Y-%m-%d')})"
      end
    end
    
    # Check documents
    documents = DocumentContent.for_place(place_id).completed
    puts "\n📄 Documents: #{documents.count}"
    
    if documents.any?
      puts "   With embeddings: #{documents.with_embeddings.count}"
      puts "   Recent docs:"
      documents.order(created_at: :desc).limit(3).each do |d|
        status = d.embedding.present? ? "✅" : "❌"
        puts "   #{status} #{d.title} (#{d.content_type})"
      end
    end
    
    # Overall status
    total_with_embeddings = transcripts.with_embeddings.count + documents.with_embeddings.count
    puts "\n🔢 Total items with embeddings: #{total_with_embeddings}"
    
    if total_with_embeddings == 0
      puts "\n⚠️  No content with embeddings found!"
      puts "   Make sure transcripts are processed and embeddings generated."
    else
      puts "\n✅ Ready for RAG queries!"
    end
  end
  
  desc "Preview context for a question without AI call"
  task :preview, [:place_id, :question] => :environment do |t, args|
    place_id = args[:place_id]&.to_i || 271
    question = args[:question] || "What programs does this school offer?"
    
    puts "🔍 RAG Context Preview"
    puts "=" * 50
    puts "Place ID: #{place_id}"
    puts "Question: #{question}"
    puts "=" * 50
    
    preview = SimpleRagService.preview_context(place_id, question)
    
    puts "📊 Results:"
    puts "  Content found: #{preview[:content_found] ? '✅ Yes' : '❌ No'}"
    puts "  Sources: #{preview[:stats][:sources_found]}"
    puts "  Tokens: #{preview[:stats][:tokens_used]}"
    
    if preview[:content_found]
      puts "\n📚 Sources:"
      preview[:sources].each_with_index do |source, i|
        puts "  #{i + 1}. #{source[:title]} (#{source[:type]})"
      end
      
      puts "\n📄 Context Preview:"
      puts "-" * 40
      puts preview[:context_preview]
      puts "-" * 40
    else
      puts "\n⚠️  No relevant content found for this question."
      puts "   Try a different question or check if content has embeddings."
    end
  end
  
  desc "Run interactive RAG session"
  task :interactive, [:place_id] => :environment do |t, args|
    place_id = args[:place_id]&.to_i || 271
    
    puts "🤖 Interactive RAG Session (Place #{place_id})"
    puts "=" * 50
    puts "Type 'exit' to quit, 'help' for commands"
    puts "=" * 50
    
    loop do
      print "\n❓ Ask a question: "
      input = STDIN.gets.chomp
      
      case input.downcase
      when 'exit', 'quit'
        puts "👋 Goodbye!"
        break
      when 'help'
        puts <<~HELP
          Commands:
            help     - Show this help
            preview  - Preview context for next question
            stats    - Show content statistics
            exit     - Quit session
          
          Or just ask any question about the school!
        HELP
      when 'stats'
        Rake::Task['rag:check_content'].execute(place_id: place_id)
      when 'preview'
        print "Question to preview: "
        question = STDIN.gets.chomp
        Rake::Task['rag:preview'].execute(place_id: place_id, question: question)
      else
        if input.present?
          puts "\n🔍 Searching..."
          result = SimpleRagService.ask_question(place_id, input)
          
          if result[:success]
            puts "\n✅ #{result[:answer]}"
            if result[:sources].any?
              puts "\n📚 Sources: #{result[:sources].map { |s| s[:title] }.join(', ')}"
            end
          else
            puts "\n❌ #{result[:error]}"
          end
        end
      end
    end
  end
end