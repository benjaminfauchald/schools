# Background job for processing uploaded documents
# Extracts text using Yomu2 gem (Apache Tika), generates embeddings, and extracts metadata
require "timeout"
require "yomu"

# Monkey patch for File.exists? compatibility with Ruby 3.3
unless File.respond_to?(:exists?)
  class << File
    alias_method :exists?, :exist?
  end
end

class ProcessDocumentJob < ApplicationJob
  queue_as :default

  # Retry configuration
  retry_on StandardError, wait: 5.seconds, attempts: 3
  retry_on Timeout::Error, wait: 10.seconds, attempts: 5

  # Discard job on certain unrecoverable errors
  discard_on ActiveRecord::RecordNotFound
  discard_on ActiveStorage::FileNotFoundError

  def perform(document)
    Rails.logger.info "Starting document processing for ID: #{document.id} (#{document.filename})"

    # Log Java availability
    java_path = `which java 2>/dev/null`.strip
    Rails.logger.info "Java path: #{java_path.present? ? java_path : 'NOT FOUND'}"
    if java_path.present?
      java_version = `java -version 2>&1 | head -n 1`.strip
      Rails.logger.info "Java version: #{java_version}"
    else
      Rails.logger.warn "Java not found in PATH: #{ENV['PATH']}"
    end

    # Validate document state
    unless document.file.attached?
      raise ArgumentError, "Document #{document.id} has no attached file"
    end

    # Create temporary file for processing
    temp_file = nil

    begin
      # Download file to temporary location
      temp_file = download_to_temp(document.file)

      # Extract text content
      extracted_text = extract_text(temp_file.path)

      # Extract metadata
      metadata = extract_metadata(temp_file.path, document)

      # Generate embedding if AI is enabled
      embedding = nil
      if document.ai_enabled? && extracted_text.present?
        embedding = generate_embedding(extracted_text)
      end

      # Update document with results
      document.update!(
        extracted_text: extracted_text,
        metadata: metadata,
        embedding: embedding,
        processing_completed: true,
        processing_failed: false,
        processing_error: nil,
        last_processed_at: Time.current
      )

      Rails.logger.info "Successfully processed document #{document.id}: #{extracted_text&.length || 0} chars extracted"

      # Broadcast update to refresh UI
      broadcast_document_update(document, "processed")

    rescue => e
      # Log error and update document
      error_message = "#{e.class}: #{e.message}"
      Rails.logger.error "Failed to process document #{document.id}: #{error_message}"
      Rails.logger.error e.backtrace.join("\n") if Rails.env.development?

      document.update!(
        processing_failed: true,
        processing_completed: false,
        processing_error: error_message,
        last_processed_at: Time.current
      )

      # Broadcast failure to UI
      broadcast_document_update(document, "failed")

      # Re-raise to trigger retry logic
      raise e

    ensure
      # Clean up temporary file
      if temp_file
        temp_file.close
        temp_file.unlink rescue nil
      end
    end
  end

  private

  def broadcast_document_update(document, status)
    # Find the school associated with this document
    school = document.place&.school

    if school
      # Broadcast to the specific document element
      document_html = ApplicationController.render(
        partial: "school_owner/schools/document_item",
        locals: { document: document },
        assigns: { school: school }
      )

      Turbo::StreamsChannel.broadcast_replace_to(
        "document_#{document.id}",
        target: "document_#{document.id}",
        html: document_html
      )
    else
      Rails.logger.warn "Cannot broadcast update for document #{document.id}: no associated school found"
    end
  end

  def download_to_temp(attached_file)
    # Create temporary file with appropriate extension
    extension = File.extname(attached_file.filename.to_s)
    temp_file = Tempfile.new([ "document", extension ], Rails.root.join("tmp"))
    temp_file.binmode

    # Download file content
    attached_file.download do |chunk|
      temp_file.write(chunk)
    end

    temp_file.flush
    temp_file.rewind
    temp_file
  end

  def extract_text(file_path)
    Rails.logger.debug "Extracting text from: #{file_path}"
    Rails.logger.debug "File exists: #{File.exist?(file_path)}"
    Rails.logger.debug "File size: #{File.exist?(file_path) ? File.size(file_path) : 'N/A'} bytes"

    begin
      # Use Yomu to extract text
      Rails.logger.debug "Creating Yomu instance for: #{file_path}"
      yomu = Yomu.new(file_path)
      Rails.logger.debug "Calling yomu.text"
      text = yomu.text
      Rails.logger.debug "Successfully extracted #{text&.length || 0} characters"
    rescue => e
      Rails.logger.error "Yomu extraction failed: #{e.class}: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
      raise e
    end

    # Clean up extracted text
    cleaned_text = clean_extracted_text(text)

    if cleaned_text.blank?
      Rails.logger.warn "No text extracted from document: #{file_path}"
      return "No text content could be extracted from this document."
    end

    Rails.logger.debug "Extracted #{cleaned_text.length} characters of text"
    cleaned_text
  end

  def extract_metadata(file_path, document)
    Rails.logger.debug "Extracting metadata from: #{file_path}"

    begin
      yomu = Yomu.new(file_path)
      raw_metadata = yomu.metadata

      # Process and clean metadata
      processed_metadata = {
        # File information
        file_info: {
          original_filename: document.original_filename,
          content_type: document.content_type,
          file_size: document.file_size,
          file_extension: document.file_extension
        },

        # Extracted Apache Tika metadata
        tika_metadata: clean_metadata(raw_metadata),

        # Processing information
        processing_info: {
          processed_at: Time.current.iso8601,
          yomu_version: Yomu::VERSION,
          job_class: self.class.name
        }
      }

      # Add document-specific metadata based on file type
      case document.file_extension
      when ".pdf"
        processed_metadata[:pdf_info] = extract_pdf_specific_metadata(raw_metadata)
      when ".doc", ".docx"
        processed_metadata[:word_info] = extract_word_specific_metadata(raw_metadata)
      when ".xls", ".xlsx"
        processed_metadata[:excel_info] = extract_excel_specific_metadata(raw_metadata)
      when ".ppt", ".pptx"
        processed_metadata[:powerpoint_info] = extract_powerpoint_specific_metadata(raw_metadata)
      end

      processed_metadata

    rescue => e
      Rails.logger.error "Failed to extract metadata: #{e.message}"

      # Return basic metadata even if extraction fails
      {
        file_info: {
          original_filename: document.original_filename,
          content_type: document.content_type,
          file_size: document.file_size,
          file_extension: document.file_extension
        },
        processing_info: {
          processed_at: Time.current.iso8601,
          metadata_extraction_error: e.message
        }
      }
    end
  end

  def generate_embedding(text)
    # Placeholder for OpenAI API integration
    # In a real implementation, this would call OpenAI's embeddings API
    Rails.logger.debug "Generating embedding for #{text.length} characters of text"

    # For now, return nil to indicate embeddings are not yet implemented
    # This allows the rest of the system to work without AI features
    Rails.logger.info "Embedding generation not yet implemented - returning nil"
    nil

    # Future implementation would look like:
    # begin
    #   client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
    #   response = client.embeddings(
    #     parameters: {
    #       model: 'text-embedding-ada-002',
    #       input: text.truncate(8000) # Respect token limits
    #     }
    #   )
    #
    #   embedding_array = response.dig('data', 0, 'embedding')
    #   return nil unless embedding_array&.length == 1536
    #
    #   # Convert to pgvector format
    #   "[#{embedding_array.join(',')}]"
    # rescue => e
    #   Rails.logger.error "Failed to generate embedding: #{e.message}"
    #   nil
    # end
  end

  def clean_extracted_text(text)
    return nil if text.blank?

    # Basic text cleaning
    cleaned = text.strip

    # Remove excessive whitespace
    cleaned = cleaned.gsub(/\s+/, " ")

    # Remove control characters but keep newlines and tabs
    cleaned = cleaned.gsub(/[[:cntrl:]&&[^\n\t]]/, "")

    # Limit length to prevent extremely large texts
    if cleaned.length > 100_000
      Rails.logger.warn "Text truncated from #{cleaned.length} to 100,000 characters"
      cleaned = cleaned[0...100_000] + "\n\n[Text truncated...]"
    end

    cleaned
  end

  def clean_metadata(raw_metadata)
    return {} unless raw_metadata.is_a?(Hash)

    # Remove empty values and clean up keys
    cleaned = {}
    raw_metadata.each do |key, value|
      next if value.blank?

      # Clean up key names
      clean_key = key.to_s.downcase.gsub(/[^a-z0-9_]/, "_")
      cleaned[clean_key] = value.is_a?(String) ? value.strip : value
    end

    cleaned
  end

  def extract_pdf_specific_metadata(metadata)
    {
      title: metadata["title"],
      author: metadata["creator"] || metadata["author"],
      subject: metadata["subject"],
      keywords: metadata["keywords"],
      pages: metadata["xmpTPg:NPages"] || metadata["meta:page-count"],
      created: metadata["dcterms:created"] || metadata["meta:creation-date"],
      modified: metadata["dcterms:modified"] || metadata["meta:save-date"]
    }.compact
  end

  def extract_word_specific_metadata(metadata)
    {
      title: metadata["title"],
      author: metadata["creator"] || metadata["meta:author"],
      subject: metadata["subject"],
      keywords: metadata["keywords"],
      pages: metadata["meta:page-count"],
      word_count: metadata["meta:word-count"],
      character_count: metadata["meta:character-count"],
      created: metadata["dcterms:created"] || metadata["meta:creation-date"],
      modified: metadata["dcterms:modified"] || metadata["meta:save-date"],
      company: metadata["meta:company"],
      application: metadata["Application-Name"]
    }.compact
  end

  def extract_excel_specific_metadata(metadata)
    {
      title: metadata["title"],
      author: metadata["creator"] || metadata["meta:author"],
      subject: metadata["subject"],
      keywords: metadata["keywords"],
      sheets: metadata["meta:sheet-count"],
      created: metadata["dcterms:created"] || metadata["meta:creation-date"],
      modified: metadata["dcterms:modified"] || metadata["meta:save-date"],
      company: metadata["meta:company"],
      application: metadata["Application-Name"]
    }.compact
  end

  def extract_powerpoint_specific_metadata(metadata)
    {
      title: metadata["title"],
      author: metadata["creator"] || metadata["meta:author"],
      subject: metadata["subject"],
      keywords: metadata["keywords"],
      slides: metadata["meta:slide-count"],
      created: metadata["dcterms:created"] || metadata["meta:creation-date"],
      modified: metadata["dcterms:modified"] || metadata["meta:save-date"],
      company: metadata["meta:company"],
      application: metadata["Application-Name"]
    }.compact
  end
end
