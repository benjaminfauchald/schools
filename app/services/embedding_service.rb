class EmbeddingService
  include HTTParty
  
  OPENAI_EMBEDDING_URL = 'https://api.openai.com/v1/embeddings'
  EMBEDDING_MODEL = 'text-embedding-3-small' # 1536 dimensions, cost-effective
  MAX_TOKENS = 8192 # Max tokens per request for text-embedding-3-small
  
  class << self
    def generate_embedding(text)
      return nil if text.blank?
      
      # Truncate text if too long
      text = truncate_text(text, MAX_TOKENS)
      
      response = HTTParty.post(
        OPENAI_EMBEDDING_URL,
        headers: {
          'Authorization' => "Bearer #{openai_api_key}",
          'Content-Type' => 'application/json'
        },
        body: {
          model: EMBEDDING_MODEL,
          input: text.strip,
          encoding_format: 'float'
        }.to_json,
        timeout: 30
      )
      
      if response.success?
        response.dig('data', 0, 'embedding')
      else
        Rails.logger.error "OpenAI Embedding Error: #{response.code} - #{response.message}"
        Rails.logger.error "Response body: #{response.body}"
        nil
      end
    rescue => e
      Rails.logger.error "OpenAI Embedding Exception: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    end
    
    # For batch processing (more efficient for multiple texts)
    def generate_embeddings(texts)
      return [] if texts.blank?
      
      # Filter and truncate texts
      valid_texts = texts.compact.map { |text| truncate_text(text, MAX_TOKENS) }
      return [] if valid_texts.empty?
      
      response = HTTParty.post(
        OPENAI_EMBEDDING_URL,
        headers: {
          'Authorization' => "Bearer #{openai_api_key}",
          'Content-Type' => 'application/json'
        },
        body: {
          model: EMBEDDING_MODEL,
          input: valid_texts,
          encoding_format: 'float'
        }.to_json,
        timeout: 60
      )
      
      if response.success?
        response['data'].map { |item| item['embedding'] }
      else
        Rails.logger.error "OpenAI Batch Embedding Error: #{response.code} - #{response.message}"
        Rails.logger.error "Response body: #{response.body}"
        []
      end
    rescue => e
      Rails.logger.error "OpenAI Batch Embedding Exception: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      []
    end
    
    # Estimate token count (approximate)
    def estimate_tokens(text)
      return 0 if text.blank?
      
      # Rough approximation: 1 token ≈ 4 characters for English text
      (text.length / 4.0).ceil
    end
    
    # Check if text exceeds token limit
    def exceeds_token_limit?(text, limit = MAX_TOKENS)
      estimate_tokens(text) > limit
    end
    
    # Truncate text to fit within token limit
    def truncate_text(text, token_limit = MAX_TOKENS)
      return text if text.blank?
      
      estimated_tokens = estimate_tokens(text)
      
      if estimated_tokens <= token_limit
        text
      else
        # Truncate to approximately fit token limit
        # Conservative approach: use 3.5 chars per token to be safe
        char_limit = (token_limit * 3.5).to_i
        text.truncate(char_limit, omission: '...')
      end
    end
    
    # Chunk text into smaller pieces if needed
    def chunk_text(text, max_tokens_per_chunk = 1000, overlap_tokens = 100)
      return [text] if text.blank? || estimate_tokens(text) <= max_tokens_per_chunk
      
      chunks = []
      sentences = text.split(/[.!?]+/)
      current_chunk = ""
      
      sentences.each do |sentence|
        sentence = sentence.strip
        next if sentence.empty?
        
        test_chunk = current_chunk.empty? ? sentence : "#{current_chunk}. #{sentence}"
        
        if estimate_tokens(test_chunk) <= max_tokens_per_chunk
          current_chunk = test_chunk
        else
          # Add current chunk if it's not empty
          chunks << current_chunk unless current_chunk.empty?
          
          # Start new chunk
          if estimate_tokens(sentence) <= max_tokens_per_chunk
            current_chunk = sentence
          else
            # If single sentence is too long, split it by words
            words = sentence.split(' ')
            word_chunks = []
            current_word_chunk = ""
            
            words.each do |word|
              test_word_chunk = current_word_chunk.empty? ? word : "#{current_word_chunk} #{word}"
              
              if estimate_tokens(test_word_chunk) <= max_tokens_per_chunk
                current_word_chunk = test_word_chunk
              else
                word_chunks << current_word_chunk unless current_word_chunk.empty?
                current_word_chunk = word
              end
            end
            
            word_chunks << current_word_chunk unless current_word_chunk.empty?
            chunks.concat(word_chunks)
            current_chunk = ""
          end
        end
      end
      
      # Add the last chunk if it exists
      chunks << current_chunk unless current_chunk.empty?
      
      # Add overlap between chunks if specified
      if overlap_tokens > 0 && chunks.length > 1
        overlapped_chunks = []
        
        chunks.each_with_index do |chunk, index|
          if index == 0
            overlapped_chunks << chunk
          else
            # Get overlap from previous chunk
            prev_words = chunks[index - 1].split(' ')
            overlap_words = prev_words.last([overlap_tokens / 4, prev_words.length].min)
            overlapped_chunk = "#{overlap_words.join(' ')} #{chunk}"
            overlapped_chunks << overlapped_chunk
          end
        end
        
        chunks = overlapped_chunks
      end
      
      chunks.compact.reject(&:empty?)
    end
    
    private
    
    def openai_api_key
      ENV['OPENAI_API_KEY'] || raise('OPENAI_API_KEY environment variable not set')
    end
  end
end