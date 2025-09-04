# Transcript Cleaning Service for AI-powered transcript improvement
# Uses Azure OpenAI to clean and enhance YouTube video transcripts
class TranscriptCleaningService
  include HTTParty
  
  # Maximum text length for Azure OpenAI chat API
  MAX_TEXT_LENGTH = 12000
  
  def initialize
    validate_azure_config
  end
  
  # Clean a single transcript using AI
  def clean_transcript(transcript)
    Rails.logger.info "🧹 Cleaning transcript #{transcript.id} - #{transcript.video_title}"
    
    begin
      unless transcript.full_transcript.present?
        Rails.logger.warn "⚠️ Transcript #{transcript.id} has no full_transcript content"
        return {
          success: false,
          error: "No full transcript content available",
          transcript_cleaned: false
        }
      end
      
      # Prepare raw transcript text
      raw_text = prepare_transcript_for_cleaning(transcript.full_transcript)
      
      if raw_text.blank?
        Rails.logger.warn "⚠️ Transcript #{transcript.id} has no usable content after preparation"
        return {
          success: false,
          error: "No usable transcript content after preparation",
          transcript_cleaned: false
        }
      end
      
      # Generate cleaned transcript using Azure OpenAI
      cleaned_text = generate_cleaned_transcript(raw_text)
      
      if cleaned_text.present?
        # Update transcript with cleaned version
        transcript.update!(
          cleaned_transcript: cleaned_text,
          transcript_cleaned_at: Time.current
        )
        
        Rails.logger.info "✅ Successfully cleaned transcript #{transcript.id}"
        Rails.logger.info "📊 Original length: #{raw_text.length}, Cleaned length: #{cleaned_text.length}"
        
        {
          success: true,
          transcript_cleaned: true,
          original_length: raw_text.length,
          cleaned_length: cleaned_text.length,
          improvement_ratio: (cleaned_text.length.to_f / raw_text.length).round(2)
        }
      else
        Rails.logger.warn "⚠️ Failed to generate cleaned transcript for #{transcript.id}"
        {
          success: false,
          error: "Failed to generate cleaned transcript",
          transcript_cleaned: false
        }
      end
      
    rescue => e
      Rails.logger.error "💥 Error cleaning transcript #{transcript.id}: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      
      {
        success: false,
        error: e.message,
        transcript_cleaned: false
      }
    end
  end
  
  # Batch process multiple transcripts needing cleaning
  def batch_clean_transcripts(limit: 10)
    Rails.logger.info "🧹 Starting batch cleaning of transcripts"
    
    # Find transcripts that need cleaning
    transcripts_needing_cleaning = Transcript.processed
                                            .ai_enabled
                                            .where(cleaned_transcript: nil)
                                            .where.not(full_transcript: [nil, ''])
                                            .limit(limit)
    
    Rails.logger.info "📋 Found #{transcripts_needing_cleaning.count} transcripts needing cleaning"
    
    results = {
      processed: 0,
      failed: 0,
      skipped: 0,
      total_original_chars: 0,
      total_cleaned_chars: 0
    }
    
    transcripts_needing_cleaning.find_each do |transcript|
      Rails.logger.info "🔄 Processing transcript #{transcript.id} - #{transcript.video_title || transcript.video_id}"
      
      result = clean_transcript(transcript)
      
      if result[:success]
        results[:processed] += 1
        results[:total_original_chars] += result[:original_length] || 0
        results[:total_cleaned_chars] += result[:cleaned_length] || 0
      else
        results[:failed] += 1
        Rails.logger.error "❌ Failed to clean transcript #{transcript.id}: #{result[:error]}"
      end
      
      # Rate limiting between API calls
      sleep(1)
    end
    
    # Calculate improvement statistics
    if results[:total_original_chars] > 0
      improvement_percentage = ((results[:total_cleaned_chars].to_f / results[:total_original_chars]) * 100).round(1)
      results[:improvement_percentage] = improvement_percentage
    end
    
    Rails.logger.info "📊 Batch cleaning complete: #{results[:processed]} processed, #{results[:failed]} failed"
    results
  end
  
  private
  
  # Prepare raw transcript for AI cleaning
  def prepare_transcript_for_cleaning(raw_transcript)
    return nil if raw_transcript.blank?
    
    # Basic cleaning before sending to AI
    cleaned = raw_transcript.strip
    
    # Remove excessive whitespace
    cleaned = cleaned.gsub(/\s+/, ' ')
    
    # Truncate if too long for API
    if cleaned.length > MAX_TEXT_LENGTH
      Rails.logger.warn "📏 Truncating transcript from #{cleaned.length} to #{MAX_TEXT_LENGTH} characters"
      cleaned = cleaned[0...MAX_TEXT_LENGTH] + "..."
    end
    
    cleaned
  end
  
  # Generate cleaned transcript using Azure OpenAI Chat API
  def generate_cleaned_transcript(raw_text)
    begin
      start_time = Time.current
      
      # Build the API URL for Azure OpenAI chat
      api_url = "#{azure_endpoint}/openai/deployments/#{azure_deployment}/chat/completions?api-version=2024-02-15-preview"
      
      # Construct the cleaning prompt
      system_prompt = build_cleaning_prompt
      
      # API request payload
      payload = {
        messages: [
          { role: 'system', content: system_prompt },
          { role: 'user', content: raw_text }
        ],
        max_tokens: 4000,
        temperature: 0.3,  # Lower temperature for more consistent cleaning
        top_p: 0.9
      }
      
      Rails.logger.debug "🌐 Making Azure chat API call for transcript cleaning"
      
      # Make API request to Azure OpenAI
      response = HTTParty.post(
        api_url,
        headers: {
          'api-key' => azure_api_key,
          'Content-Type' => 'application/json'
        },
        body: payload.to_json,
        timeout: 60  # Longer timeout for transcript processing
      )
      
      processing_time = Time.current - start_time
      Rails.logger.debug "⏱️ Azure chat API call took #{processing_time.round(3)}s"
      
      unless response.success?
        Rails.logger.error "❌ Azure OpenAI Chat API Error: #{response.code}"
        Rails.logger.error "📄 Response Headers: #{response.headers.inspect}"
        Rails.logger.error "📝 Response Body: #{response.body}"
        return nil
      end
      
      result = response.parsed_response
      cleaned_content = result.dig('choices', 0, 'message', 'content')
      
      unless cleaned_content.present?
        Rails.logger.error "❌ No cleaned content returned from Azure OpenAI"
        return nil
      end
      
      Rails.logger.debug "✅ Generated cleaned transcript"
      Rails.logger.debug "🔢 Token usage: #{result.dig('usage', 'total_tokens')} tokens"
      Rails.logger.debug "📏 Cleaned content length: #{cleaned_content.length} characters"
      
      cleaned_content.strip
      
    rescue => e
      Rails.logger.error "💥 Exception generating cleaned transcript: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.first(3).join("\n")
      nil
    end
  end
  
  # Build the cleaning prompt for consistent results
  def build_cleaning_prompt
    <<~PROMPT
      You are a professional transcript editor. Your job is to clean and improve YouTube video transcripts while preserving the original meaning and speaker's voice.
      
      Please:
      1. Remove audio cues like [Music], [Applause], [Laughter], [Background noise], etc.
      2. Fix obvious grammatical and spelling errors
      3. Improve sentence structure and flow while keeping the original tone
      4. Remove repetitive filler words and false starts
      5. Ensure proper punctuation and capitalization
      6. Maintain the speaker's natural speaking style and personality
      7. Do not add information that wasn't in the original transcript
      8. Preserve important names, places, and specific details exactly as mentioned
      
      Return only the cleaned transcript without any additional commentary or formatting.
    PROMPT
  end
  
  # Azure OpenAI configuration methods (reusing existing pattern)
  def azure_api_key
    ENV['AZURE_OPENAI_API_KEY'] || raise('AZURE_OPENAI_API_KEY environment variable is required')
  end
  
  def azure_endpoint
    ENV['AZURE_OPENAI_API_ENDPOINT'] || raise('AZURE_OPENAI_API_ENDPOINT environment variable is required')
  end
  
  def azure_deployment
    ENV['AZURE_OPENAI_API_DEPLOYMENT'] || raise('AZURE_OPENAI_API_DEPLOYMENT environment variable is required')
  end
  
  def validate_azure_config
    # Ensure all required Azure OpenAI environment variables are present
    azure_api_key
    azure_endpoint
    azure_deployment
    
    # Validate endpoint format
    unless azure_endpoint.start_with?('https://')
      raise 'AZURE_OPENAI_API_ENDPOINT must be a valid HTTPS URL'
    end
    
    Rails.logger.debug "🔧 Azure OpenAI configuration validated for transcript cleaning"
    Rails.logger.debug "🌐 Endpoint: #{azure_endpoint}"
    Rails.logger.debug "🚀 Deployment: #{azure_deployment}"
    
  rescue => e
    Rails.logger.error "❌ Azure OpenAI Configuration Error: #{e.message}"
    raise "Azure OpenAI Configuration Error: #{e.message}"
  end
end