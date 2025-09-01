# RAG Query Examples
# Run these in Rails console: rails console
# Load this file: load 'lib/rag_examples.rb'

class RagExamples
  # Example 1: Simple question answering
  def self.basic_example
    place_id = 271  # Your school ID
    question = "What is the school's teaching philosophy?"
    
    puts "🔍 Question: #{question}"
    puts "📍 Searching place ID: #{place_id}"
    puts "=" * 50
    
    result = SimpleRagService.ask_question(place_id, question)
    
    if result[:success]
      puts "✅ Answer found!"
      puts "\n📝 Answer:"
      puts result[:answer]
      
      puts "\n📚 Sources used (#{result[:context_stats][:sources_found]}):"
      result[:sources].each_with_index do |source, i|
        puts "  #{i + 1}. #{source[:title]} (relevance: #{source[:relevance_score]})"
      end
      
      puts "\n📊 Stats:"
      puts "  - Context tokens: #{result[:context_stats][:tokens_used]}"
      puts "  - AI tokens used: #{result[:ai_usage]['total_tokens'] || 'N/A'}"
      
    else
      puts "❌ Error: #{result[:error]}"
    end
    
    result
  end
  
  # Example 2: Preview context without AI call
  def self.preview_example
    place_id = 271
    question = "What extracurricular activities are available?"
    
    puts "🔍 Preview for: #{question}"
    puts "=" * 50
    
    preview = SimpleRagService.preview_context(place_id, question)
    
    puts "📊 Content found: #{preview[:content_found]}"
    puts "📚 Sources: #{preview[:stats][:sources_found]}"
    puts "🔢 Tokens: #{preview[:stats][:tokens_used]}"
    
    if preview[:content_found]
      puts "\n📄 Context preview:"
      puts preview[:context_preview]
      
      puts "\n📂 Sources:"
      preview[:sources].each do |source|
        puts "  - #{source[:title]} (#{source[:type]})"
      end
    else
      puts "\n⚠️ No relevant content found for this question"
    end
    
    preview
  end
  
  # Example 3: Different response styles
  def self.style_examples
    place_id = 271
    question = "What are the admission requirements?"
    
    styles = ['helpful', 'formal', 'friendly', 'detailed']
    
    styles.each do |style|
      puts "\n" + "=" * 60
      puts "📝 Style: #{style.upcase}"
      puts "=" * 60
      
      result = SimpleRagService.ask_question(place_id, question, style: style)
      
      if result[:success]
        puts result[:answer]
      else
        puts "Error: #{result[:error]}"
      end
    end
  end
  
  # Example 4: Multiple questions (conversation)
  def self.conversation_example
    place_id = 271
    
    messages = [
      { role: 'user', content: 'What programs does the school offer?' },
      { role: 'user', content: 'What are the facilities like?' },
      { role: 'user', content: 'How can I apply for admission?' }
    ]
    
    puts "💬 Starting conversation with #{messages.length} questions"
    puts "=" * 60
    
    conversation = SimpleRagService.conversation(place_id, messages)
    
    conversation[:conversation_results].each do |turn|
      puts "\n❓ Q#{turn[:turn] + 1}: #{turn[:question]}"
      
      if turn[:result][:success]
        puts "✅ A: #{turn[:result][:answer]}"
        puts "   📚 Sources: #{turn[:result][:context_stats][:sources_found]}"
      else
        puts "❌ Error: #{turn[:result][:error]}"
      end
    end
    
    puts "\n📊 Conversation Summary:"
    puts "  Total sources used: #{conversation[:total_sources_used]}"
    
    conversation
  end
  
  # Example 5: Search specific content types
  def self.content_type_example
    place_id = 271
    question = "What facilities does the school have?"
    
    # Try different content types
    content_types = [
      ['transcript'],           # Only videos
      ['pdf_document'],         # Only documents  
      ['transcript', 'pdf_document']  # Both
    ]
    
    content_types.each do |types|
      puts "\n" + "=" * 50
      puts "🔍 Searching: #{types.join(', ')}"
      puts "=" * 50
      
      result = SimpleRagService.ask_question(place_id, question, content_types: types)
      
      if result[:success] && result[:context_stats][:content_found]
        puts "✅ Found #{result[:context_stats][:sources_found]} sources"
        puts "📝 Answer: #{result[:answer].truncate(200)}"
        
        puts "📚 Source types:"
        result[:sources].each do |source|
          puts "  - #{source[:type]}: #{source[:title].truncate(50)}"
        end
      else
        puts "❌ No content found or error: #{result[:error]}"
      end
    end
  end
  
  # Utility: Check what content is available
  def self.check_available_content(place_id = 271)
    puts "📊 Content availability for place #{place_id}:"
    puts "=" * 50
    
    # Check transcripts
    transcript_count = Transcript.for_place(place_id).processed.count
    puts "🎥 Processed transcripts: #{transcript_count}"
    
    if transcript_count > 0
      recent_transcripts = Transcript.for_place(place_id)
                                   .processed
                                   .order(created_at: :desc)
                                   .limit(3)
                                   .pluck(:video_title, :created_at)
      
      puts "   Recent videos:"
      recent_transcripts.each do |title, created_at|
        puts "   - #{title} (#{created_at.strftime('%Y-%m-%d')})"
      end
    end
    
    # Check documents
    document_count = DocumentContent.for_place(place_id).completed.count
    puts "📄 Processed documents: #{document_count}"
    
    if document_count > 0
      recent_docs = DocumentContent.for_place(place_id)
                                  .completed
                                  .order(created_at: :desc)
                                  .limit(3)
                                  .pluck(:title, :content_type, :created_at)
      
      puts "   Recent documents:"
      recent_docs.each do |title, type, created_at|
        puts "   - #{title} (#{type}, #{created_at.strftime('%Y-%m-%d')})"
      end
    end
    
    # Check embeddings
    with_embeddings = Transcript.for_place(place_id).with_embeddings.count +
                     DocumentContent.for_place(place_id).with_embeddings.count
    puts "🔢 Items with embeddings: #{with_embeddings}"
    
    {
      transcripts: transcript_count,
      documents: document_count,
      with_embeddings: with_embeddings
    }
  end
  
  # Run all examples
  def self.run_all_examples(place_id = 271)
    puts "🚀 Running all RAG examples for place #{place_id}"
    puts "=" * 70
    
    check_available_content(place_id)
    
    puts "\n1️⃣ Basic Example:"
    basic_example
    
    puts "\n\n2️⃣ Preview Example:"
    preview_example
    
    puts "\n\n3️⃣ Style Examples:"
    style_examples
    
    puts "\n\n4️⃣ Conversation Example:"
    conversation_example
    
    puts "\n\n5️⃣ Content Type Example:"
    content_type_example
    
    puts "\n✅ All examples completed!"
  end
end

# Quick start instructions
puts <<~INSTRUCTIONS

🎉 RAG Examples Loaded!

Quick start:
  RagExamples.check_available_content      # See what content is available
  RagExamples.basic_example               # Simple Q&A
  RagExamples.preview_example             # Preview context without AI
  RagExamples.run_all_examples            # Run all examples

Or try a custom query:
  SimpleRagService.ask_question(271, "Your question here")

INSTRUCTIONS