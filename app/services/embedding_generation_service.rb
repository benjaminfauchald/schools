# Embedding Generation Service for Azure OpenAI integration
# Generates vector embeddings for transcripts and transcript segments using Azure OpenAI
class EmbeddingGenerationService
  include HTTParty

  # Standard OpenAI embedding dimension
  EMBEDDING_DIMENSION = 1536
  MAX_TEXT_LENGTH = 8000 # Azure OpenAI token limit for embeddings

  def initialize
    validate_azure_config
  end

  # Process any embeddable content (transcript or document)
  def process_content(content_item)
    case content_item.class.name
    when "Transcript"
      process_transcript(content_item)
    when "Document"
      process_document(content_item)
    else
      Rails.logger.error "❌ Unsupported content type: #{content_item.class.name}"
      { success: false, error: "Unsupported content type" }
    end
  end

  # Generate embeddings for a transcript (full transcript only, no segments)
  def process_transcript(transcript)
    Rails.logger.info "🔮 Generating embedding for transcript #{transcript.id}"

    begin
      # Use cleaned transcript if available, otherwise fall back to full transcript
      content = transcript.best_transcript_content

      unless content.present?
        Rails.logger.warn "⚠️ Transcript #{transcript.id} has no usable content for embedding"
        return {
          success: false,
          error: "No usable transcript content available",
          transcript_processed: false
        }
      end

      Rails.logger.info "📄 Processing transcript content (#{content.length} chars) - #{transcript.cleaned? ? 'cleaned' : 'raw'} version"

      # Truncate content if too long
      truncated_content = truncate_content(content)
      embedding_vector = generate_embedding(truncated_content)

      if embedding_vector
        # Store in pgvector column for similarity search
        transcript.update!(
          vector_embedding: pgvector_from_array(embedding_vector),
          embedding_generated_at: Time.current,
          ai_enabled: true
        )
        Rails.logger.info "✅ Generated embedding for transcript #{transcript.id} (#{transcript.cleaned? ? 'from cleaned content' : 'from raw content'})"

        {
          success: true,
          transcript_processed: true,
          content_type: transcript.cleaned? ? "cleaned" : "raw",
          content_length: content.length
        }
      else
        Rails.logger.warn "⚠️ Failed to generate embedding for transcript #{transcript.id}"
        {
          success: false,
          error: "Failed to generate embedding",
          transcript_processed: false
        }
      end

    rescue => e
      Rails.logger.error "💥 Error processing transcript #{transcript.id}: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")

      {
        success: false,
        error: e.message,
        transcript_processed: false
      }
    end
  end

  # Generate embeddings for a document
  def process_document(document)
    Rails.logger.info "🔮 Generating embeddings for document #{document.id} - #{document.filename}"

    begin
      unless document.extracted_text.present?
        Rails.logger.warn "⚠️ Document #{document.id} has no extracted text"
        return {
          success: false,
          error: "No extracted text available",
          document_processed: false
        }
      end

      # Generate embedding for document content
      content = truncate_content(document.extracted_text)
      embedding_vector = generate_embedding(content)

      if embedding_vector
        # Store in pgvector column (documents already have this structure)
        document.update!(
          embedding: pgvector_from_array(embedding_vector),
          last_processed_at: Time.current
        )
        Rails.logger.info "✅ Generated embedding for document #{document.id}"

        {
          success: true,
          document_processed: true
        }
      else
        Rails.logger.warn "⚠️ Failed to generate embedding for document #{document.id}"
        {
          success: false,
          error: "Failed to generate embedding",
          document_processed: false
        }
      end

    rescue => e
      Rails.logger.error "💥 Error processing document #{document.id}: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")

      {
        success: false,
        error: e.message,
        document_processed: false
      }
    end
  end

  # Generate embedding for a single piece of text
  def generate_embedding(text)
    return nil if text.blank?

    # Clean and prepare text
    cleaned_text = clean_text_for_embedding(text)
    return nil if cleaned_text.blank?

    Rails.logger.debug "🔮 Generating embedding for #{cleaned_text.length} characters"

    # Try OpenAI API first, then Azure as fallback
    if use_openai_api?
      generate_openai_embedding(cleaned_text)
    else
      generate_azure_embedding(cleaned_text)
    end
  end

  private

  # Generate embedding using standard OpenAI API
  def generate_openai_embedding(text)
    begin
      start_time = Time.current

      # Standard OpenAI API endpoint
      api_url = "https://api.openai.com/v1/embeddings"

      # API request payload
      payload = {
        input: text,
        model: "text-embedding-ada-002",
        encoding_format: "float"
      }

      Rails.logger.debug "🌐 Making OpenAI embedding API call"
      Rails.logger.debug "🔑 Using OpenAI API (not Azure)"

      # Make API request to OpenAI
      response = HTTParty.post(
        api_url,
        headers: {
          "Authorization" => "Bearer #{openai_api_key}",
          "Content-Type" => "application/json"
        },
        body: payload.to_json,
        timeout: 30
      )

      processing_time = Time.current - start_time
      Rails.logger.debug "⏱️ OpenAI embedding API call took #{processing_time.round(3)}s"

      unless response.success?
        Rails.logger.error "❌ OpenAI Embeddings API Error: #{response.code}"
        Rails.logger.error "📄 Response Headers: #{response.headers.inspect}"
        Rails.logger.error "📝 Response Body: #{response.body}"
        return nil
      end

      result = response.parsed_response
      embedding_array = result.dig("data", 0, "embedding")

      # Validate embedding format
      unless embedding_array&.is_a?(Array) && embedding_array.length == EMBEDDING_DIMENSION
        Rails.logger.error "❌ Invalid OpenAI embedding format: expected array of #{EMBEDDING_DIMENSION} floats, got #{embedding_array&.class} with length #{embedding_array&.length}"
        return nil
      end

      Rails.logger.debug "✅ Generated #{EMBEDDING_DIMENSION}-dimensional OpenAI embedding"
      Rails.logger.debug "🔢 Token usage: #{result.dig('usage', 'total_tokens')} tokens"

      # Return as array for conversion to pgvector format
      embedding_array

    rescue => e
      Rails.logger.error "💥 Exception generating OpenAI embedding: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.first(3).join("\n")
      nil
    end
  end

  # Generate embedding using Azure OpenAI API (fallback)
  def generate_azure_embedding(text)
    begin
      start_time = Time.current

      # Build the API URL for Azure OpenAI embeddings
      api_url = "#{azure_endpoint}/openai/deployments/#{azure_embedding_deployment}/embeddings?api-version=2024-02-15-preview"

      # API request payload
      payload = {
        input: text,
        model: "text-embedding-ada-002"
      }

      Rails.logger.debug "🌐 Making Azure embedding API call to: #{api_url}"
      Rails.logger.debug "🚀 Using deployment: #{azure_embedding_deployment}"

      # Make API request to Azure OpenAI
      response = HTTParty.post(
        api_url,
        headers: {
          "api-key" => azure_api_key,
          "Content-Type" => "application/json"
        },
        body: payload.to_json,
        timeout: 30
      )

      processing_time = Time.current - start_time
      Rails.logger.debug "⏱️ Azure embedding API call took #{processing_time.round(3)}s"

      unless response.success?
        Rails.logger.error "❌ Azure OpenAI Embeddings API Error: #{response.code}"
        Rails.logger.error "📄 Response Headers: #{response.headers.inspect}"
        Rails.logger.error "📝 Response Body: #{response.body}"
        return nil
      end

      result = response.parsed_response
      embedding_array = result.dig("data", 0, "embedding")

      # Validate embedding format
      unless embedding_array&.is_a?(Array) && embedding_array.length == EMBEDDING_DIMENSION
        Rails.logger.error "❌ Invalid Azure embedding format: expected array of #{EMBEDDING_DIMENSION} floats, got #{embedding_array&.class} with length #{embedding_array&.length}"
        return nil
      end

      Rails.logger.debug "✅ Generated #{EMBEDDING_DIMENSION}-dimensional Azure embedding"
      Rails.logger.debug "🔢 Token usage: #{result.dig('usage', 'total_tokens')} tokens"

      # Return as array for conversion to pgvector format
      embedding_array

    rescue => e
      Rails.logger.error "💥 Exception generating Azure embedding: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.first(3).join("\n")
      nil
    end
  end

  # Determine which API to use
  def use_openai_api?
    # Use OpenAI API if OPENAI_API_KEY is available and we're not forcing Azure
    ENV["OPENAI_API_KEY"].present? && ENV["FORCE_AZURE_EMBEDDINGS"] != "true"
  end

  # OpenAI API key
  def openai_api_key
    ENV["OPENAI_API_KEY"] || raise("OPENAI_API_KEY environment variable is required for OpenAI embeddings")
  end

  # Batch process all content types missing embeddings
  def batch_process_missing_embeddings(limit: 10, content_type: :all)
    Rails.logger.info "🔄 Starting batch processing of content missing embeddings"

    results = {
      processed: 0,
      failed: 0,
      skipped: 0,
      total_segments_processed: 0,
      total_segments_failed: 0,
      content_types: {}
    }

    # Process transcripts
    if content_type == :all || content_type == :transcripts
      transcript_results = batch_process_transcripts_missing_embeddings(limit: limit)
      results[:processed] += transcript_results[:processed]
      results[:failed] += transcript_results[:failed]
      results[:total_segments_processed] += transcript_results[:total_segments_processed]
      results[:total_segments_failed] += transcript_results[:total_segments_failed]
      results[:content_types][:transcripts] = transcript_results
    end

    # Process documents
    if content_type == :all || content_type == :documents
      document_results = batch_process_documents_missing_embeddings(limit: limit)
      results[:processed] += document_results[:processed]
      results[:failed] += document_results[:failed]
      results[:content_types][:documents] = document_results
    end

    Rails.logger.info "📊 Total batch processing complete: #{results[:processed]} processed, #{results[:failed]} failed"
    results
  end

  # Batch process multiple transcripts that are missing embeddings
  def batch_process_transcripts_missing_embeddings(limit: 10)
    Rails.logger.info "📹 Batch processing transcripts missing embeddings"

    # Find transcripts that need embeddings (using new vector_embedding column)
    transcripts_needing_embeddings = Transcript.processed
                                               .ai_enabled
                                               .where(vector_embedding: nil)
                                               .or(Transcript.processed.ai_enabled.where(embedding_generated_at: nil))
                                               .limit(limit)

    Rails.logger.info "📋 Found #{transcripts_needing_embeddings.count} transcripts needing embeddings"

    results = {
      processed: 0,
      failed: 0,
      skipped: 0,
      total_segments_processed: 0,
      total_segments_failed: 0
    }

    transcripts_needing_embeddings.find_each do |transcript|
      Rails.logger.info "🔄 Processing transcript #{transcript.id} - #{transcript.video_title || transcript.video_id}"

      result = process_transcript(transcript)

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

    Rails.logger.info "📊 Transcript batch processing complete: #{results[:processed]} processed, #{results[:failed]} failed"
    Rails.logger.info "📊 Segments: #{results[:total_segments_processed]} processed, #{results[:total_segments_failed]} failed"

    results
  end

  # Batch process multiple documents that are missing embeddings
  def batch_process_documents_missing_embeddings(limit: 10)
    Rails.logger.info "📄 Batch processing documents missing embeddings"

    # Find documents that need embeddings
    documents_needing_embeddings = Document.processing_completed
                                          .ai_enabled
                                          .where(embedding: nil)
                                          .where.not(extracted_text: [ nil, "" ])
                                          .limit(limit)

    Rails.logger.info "📋 Found #{documents_needing_embeddings.count} documents needing embeddings"

    results = {
      processed: 0,
      failed: 0,
      skipped: 0
    }

    documents_needing_embeddings.find_each do |document|
      Rails.logger.info "🔄 Processing document #{document.id} - #{document.filename}"

      result = process_document(document)

      if result[:success]
        results[:processed] += 1
      else
        results[:failed] += 1
        Rails.logger.error "❌ Failed to process document #{document.id}: #{result[:error]}"
      end

      # Rate limiting between documents
      sleep(0.5)
    end

    Rails.logger.info "📊 Document batch processing complete: #{results[:processed]} processed, #{results[:failed]} failed"
    results
  end

  # Convert array to pgvector format for database storage
  def pgvector_from_array(embedding_array)
    return nil unless embedding_array.is_a?(Array) && embedding_array.length == EMBEDDING_DIMENSION

    # Convert to pgvector string format: "[1.0, 2.0, 3.0, ...]"
    "[#{embedding_array.join(',')}]"
  end

  # Convert pgvector format back to array (for compatibility)
  def array_from_pgvector(pgvector_string)
    return nil unless pgvector_string.present?

    # Remove brackets and split by comma
    pgvector_string.tr("[]", "").split(",").map(&:to_f)
  end

  private

  # Generate mock embeddings for development/testing
  def generate_mock_embedding(text)
    Rails.logger.info "🎭 Generating mock embedding for development"

    # Create a deterministic but varied embedding based on text content
    # This ensures same text always gets same embedding (good for testing)
    seed = text.hash.abs % 10000
    random = Random.new(seed)

    # Generate 1536 random floats between -1 and 1 (typical embedding range)
    mock_embedding = Array.new(EMBEDDING_DIMENSION) { random.rand(-1.0..1.0) }

    # Normalize to unit vector (common for embeddings)
    magnitude = Math.sqrt(mock_embedding.map { |x| x * x }.sum)
    normalized_embedding = mock_embedding.map { |x| x / magnitude }

    Rails.logger.debug "✅ Generated mock #{EMBEDDING_DIMENSION}-dimensional embedding"
    normalized_embedding
  end

  def clean_text_for_embedding(text)
    return nil if text.blank?

    # Basic text cleaning for embeddings
    cleaned = text.strip

    # Remove excessive whitespace
    cleaned = cleaned.gsub(/\s+/, " ")

    # Remove control characters except newlines
    cleaned = cleaned.gsub(/[[:cntrl:]&&[^\n]]/, "")

    # Truncate if too long
    cleaned = truncate_content(cleaned)

    cleaned
  end

  def truncate_content(text, max_length: MAX_TEXT_LENGTH)
    return text if text.length <= max_length

    # Truncate but try to break at word boundaries
    truncated = text[0...max_length]
    last_space = truncated.rindex(" ")

    if last_space && last_space > max_length * 0.8
      truncated = truncated[0...last_space]
    end

    Rails.logger.debug "📏 Truncated text from #{text.length} to #{truncated.length} characters"
    truncated
  end

  # Azure OpenAI configuration methods (matching AiChatService pattern)
  def azure_api_key
    ENV["AZURE_OPENAI_API_KEY"] || raise("AZURE_OPENAI_API_KEY environment variable is required")
  end

  def azure_endpoint
    ENV["AZURE_OPENAI_API_ENDPOINT"] || raise("AZURE_OPENAI_API_ENDPOINT environment variable is required")
  end

  def azure_embedding_deployment
    # Try embedding-specific deployment first, fall back to main deployment
    deployment = ENV["AZURE_OPENAI_EMBEDDING_DEPLOYMENT"] || ENV["AZURE_OPENAI_API_DEPLOYMENT"]

    unless deployment
      raise("AZURE_OPENAI_EMBEDDING_DEPLOYMENT or AZURE_OPENAI_API_DEPLOYMENT environment variable is required")
    end

    # Log warning if using chat deployment for embeddings
    if deployment.include?("gpt") && ENV["AZURE_OPENAI_EMBEDDING_DEPLOYMENT"].blank?
      Rails.logger.warn "⚠️  Using chat deployment '#{deployment}' for embeddings - this may not work. Set AZURE_OPENAI_EMBEDDING_DEPLOYMENT for embedding-specific deployment."
    end

    deployment
  end

  def validate_azure_config
    # Check which API we'll use
    if use_openai_api?
      validate_openai_config
    else
      validate_azure_openai_config
    end
  end

  def validate_openai_config
    # Ensure OpenAI API key is present
    openai_api_key

    Rails.logger.debug "🔧 OpenAI API configuration validated"
    Rails.logger.debug "🔑 Using standard OpenAI API for embeddings"

  rescue => e
    Rails.logger.error "❌ OpenAI API Configuration Error: #{e.message}"
    raise "OpenAI API Configuration Error: #{e.message}"
  end

  def validate_azure_openai_config
    # Ensure all required Azure OpenAI environment variables are present
    azure_api_key
    azure_endpoint
    azure_embedding_deployment

    # Validate endpoint format
    unless azure_endpoint.start_with?("https://")
      raise "AZURE_OPENAI_API_ENDPOINT must be a valid HTTPS URL"
    end

    Rails.logger.debug "🔧 Azure OpenAI configuration validated"
    Rails.logger.debug "🌐 Endpoint: #{azure_endpoint}"
    Rails.logger.debug "🚀 Embedding deployment: #{azure_embedding_deployment}"

  rescue => e
    Rails.logger.error "❌ Azure OpenAI Configuration Error: #{e.message}"
    raise "Azure OpenAI Configuration Error: #{e.message}"
  end
end
