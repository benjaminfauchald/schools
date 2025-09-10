# Document model for file uploads with AI integration
# Supports PDF, DOC/DOCX, XLS/XLSX, PPT/PPTX files with text extraction and vector embeddings
class Document < ApplicationRecord
  belongs_to :place
  has_one_attached :file

  # Validations
  validates :filename, presence: true
  validates :file_checksum, presence: true, uniqueness: { scope: :place_id, message: "This file is already uploaded: Delete the existing file and try again if you want to replace it." }
  validates :file, presence: true, on: :create
  validate :supported_file_type

  # Scopes
  scope :processing_completed, -> { where(processing_completed: true) }
  scope :processing_failed, -> { where(processing_failed: true) }
  scope :pending_processing, -> { where(processing_completed: false, processing_failed: false) }
  scope :ai_enabled, -> { where(ai_enabled: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_embeddings, -> { where.not(embedding: nil) }

  # Lifecycle callbacks
  before_validation :extract_file_metadata, on: :create
  after_create :enqueue_processing_job
  before_destroy :cleanup_vector_data
  after_destroy :cleanup_file_storage

  # Supported file types
  SUPPORTED_MIME_TYPES = [
    "application/pdf",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.ms-excel",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "application/vnd.ms-powerpoint",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation"
  ].freeze

  SUPPORTED_EXTENSIONS = [ ".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx" ].freeze

  # Instance methods

  def processing_status
    return :completed if processing_completed?
    return :failed if processing_failed?
    return :processing if created_at < 5.minutes.ago && !processing_completed? && !processing_failed?
    :pending
  end

  def processing_status_display
    case processing_status
    when :completed then "✅ Processed"
    when :failed then "❌ Failed"
    when :processing then "🔄 Processing..."
    when :pending then "⏳ Pending"
    end
  end

  def can_reprocess?
    processing_failed? || processing_completed?
  end

  def reprocess!
    return false unless can_reprocess?

    update!(
      processing_completed: false,
      processing_failed: false,
      processing_error: nil,
      extracted_text: nil,
      embedding: nil,
      metadata: nil,
      last_processed_at: nil
    )

    # Broadcast processing status update
    broadcast_status_update("processing")

    ProcessDocumentJob.perform_later(self)
    true
  end

  def file_extension
    return nil unless original_filename.present?
    File.extname(original_filename).downcase
  end

  def file_type_display
    case file_extension
    when ".pdf" then "PDF Document"
    when ".doc", ".docx" then "Word Document"
    when ".xls", ".xlsx" then "Excel Spreadsheet"
    when ".ppt", ".pptx" then "PowerPoint Presentation"
    else "Document"
    end
  end

  def file_size_display
    return "Unknown size" unless file_size.present?

    if file_size >= 1.megabyte
      "#{(file_size.to_f / 1.megabyte).round(1)} MB"
    elsif file_size >= 1.kilobyte
      "#{(file_size.to_f / 1.kilobyte).round(1)} KB"
    else
      "#{file_size} bytes"
    end
  end

  def download_url
    return nil unless file.attached?
    begin
      Rails.application.routes.url_helpers.rails_blob_path(file, disposition: "attachment")
    rescue => e
      Rails.logger.error "Failed to generate download URL for document #{id}: #{e.message}"
      nil
    end
  end

  def preview_url
    return nil unless file.attached?
    begin
      Rails.application.routes.url_helpers.rails_blob_path(file, disposition: "inline")
    rescue => e
      Rails.logger.error "Failed to generate preview URL for document #{id}: #{e.message}"
      nil
    end
  end

  def has_extracted_text?
    extracted_text.present?
  end

  def has_embedding?
    embedding.present?
  end

  def text_preview(limit: 200)
    return "No text extracted" unless has_extracted_text?

    preview = extracted_text.strip
    preview.length > limit ? "#{preview[0..limit-1]}..." : preview
  end

  def increment_download_count!
    increment!(:download_count)
  end

  # Class methods

  def self.duplicate_exists?(checksum, place_id)
    exists?(file_checksum: checksum, place_id: place_id)
  end

  def self.find_similar_by_embedding(embedding_vector, limit: 5, exclude_ids: [])
    return none unless embedding_vector.present?

    scope = ai_enabled.with_embeddings
    scope = scope.where.not(id: exclude_ids) if exclude_ids.any?

    # Use pgvector cosine similarity search
    scope.order(Arel.sql("embedding <=> '#{embedding_vector}'::vector"))
         .limit(limit)
  end

  def self.search_by_text(query, limit: 10)
    return none if query.blank?

    # Normalize query for better matching
    normalized_query = normalize_search_query(query)

    # Extract meaningful keywords from the query
    keywords = extract_keywords(query)

    # Build search conditions for both exact and normalized queries
    search_conditions = []
    search_params = []

    # Original query search (for exact phrase matches)
    search_conditions << "extracted_text ILIKE ?"
    search_params << "%#{query}%"

    # Normalized query search (if different from original)
    if normalized_query != query
      search_conditions << "extracted_text ILIKE ?"
      search_params << "%#{normalized_query}%"
    end

    # Keyword-based search (more flexible)
    if keywords.any?
      # Use OR condition for individual keywords to be more permissive
      keyword_conditions = keywords.map { "extracted_text ILIKE ?" }.join(" OR ")
      search_conditions << "(#{keyword_conditions})"
      search_params.concat(keywords.map { |word| "%#{word}%" })

      # Also try combinations of keywords
      if keywords.length >= 2
        # Try pairs of keywords with AND (more specific matches)
        keywords.combination(2).each do |word1, word2|
          search_conditions << "(extracted_text ILIKE ? AND extracted_text ILIKE ?)"
          search_params.concat([ "%#{word1}%", "%#{word2}%" ])
        end
      end
    end

    where(search_conditions.join(" OR "), *search_params)
      .processing_completed
      .limit(limit)
      .order(:filename)
  end

  # Normalize search query to handle punctuation and formatting variations
  def self.normalize_search_query(query)
    # Remove common punctuation that might interfere with matching
    normalized = query.gsub(/[,\.;:!?]/, " ")
    # Collapse multiple spaces
    normalized = normalized.gsub(/\s+/, " ")
    # Trim whitespace
    normalized.strip
  end

  # Extract meaningful keywords from a query by removing stop words and cleaning punctuation
  def self.extract_keywords(query)
    # Common English stop words to exclude from search
    stop_words = %w[
      a an and are as at be been by for from has he in is it its of on or that the
      to was what will with would who where when why how which this these those
      about above after against all along among any around before between both
      but can could did do does each either even every few first get given go
    ].to_set

    # Split query into words and clean them
    words = query.downcase
                .gsub(/[^\w\s]/, " ")  # Replace punctuation with spaces
                .split(/\s+/)         # Split on whitespace
                .reject(&:blank?)     # Remove empty strings
                .reject { |word| stop_words.include?(word) }  # Remove stop words
                .reject { |word| word.length < 2 }           # Remove single characters
                .uniq                 # Remove duplicates

    words
  end

  def self.processing_stats
    {
      total: count,
      completed: processing_completed.count,
      failed: processing_failed.count,
      pending: pending_processing.count,
      with_embeddings: ai_enabled.with_embeddings.count
    }
  end

  def broadcast_status_update(status)
    school = place&.school

    if school
      document_html = ApplicationController.render(
        partial: "school_owner/schools/document_item",
        locals: { document: self },
        assigns: { school: school }
      )

      Turbo::StreamsChannel.broadcast_replace_to(
        "document_#{id}",
        target: "document_#{id}",
        html: document_html
      )
    else
      Rails.logger.warn "Cannot broadcast update for document #{id}: no associated school found"
    end
  end

  private

  def supported_file_type
    return unless file.attached?

    # Check MIME type
    unless SUPPORTED_MIME_TYPES.include?(file.content_type)
      errors.add(:file, "File type not supported. Supported types: PDF, Word, Excel, PowerPoint")
    end

    # Check file extension as backup
    extension = File.extname(file.filename.to_s).downcase
    unless SUPPORTED_EXTENSIONS.include?(extension)
      errors.add(:file, "File extension not supported: #{extension}")
    end
  end

  def extract_file_metadata
    return unless file.attached?

    self.original_filename = file.filename.to_s
    self.content_type = file.content_type
    self.file_size = file.byte_size

    # Generate filename if not provided
    self.filename = original_filename if filename.blank?

    # Calculate file checksum for duplicate detection
    if file.blob.present?
      # Use ActiveStorage's checksum if available
      self.file_checksum = file.blob.checksum
    else
      # Fallback to manual calculation
      file_data = file.download
      self.file_checksum = Digest::SHA256.hexdigest(file_data)
    end
  end

  def enqueue_processing_job
    Rails.logger.info "🔄 Document #{id}: Checking if processing should be enqueued"
    Rails.logger.info "🔄 Document #{id}: AI enabled: #{ai_enabled?}"
    Rails.logger.info "🔄 Document #{id}: File attached: #{file.attached?}"

    # Always process documents regardless of AI setting - we want text extraction
    if file.attached?
      Rails.logger.info "🔄 Document #{id}: Enqueuing ProcessDocumentJob"
      ProcessDocumentJob.perform_later(self)
      Rails.logger.info "🔄 Document #{id}: Job enqueued successfully"
    else
      Rails.logger.warn "⚠️ Document #{id}: No file attached, skipping job"
    end
  end

  def cleanup_vector_data
    # Log the cleanup for audit purposes
    Rails.logger.info "Cleaning up vector data for document #{id} (#{filename})"

    # The embedding column will be cleaned up automatically when the record is destroyed
    # This is just for logging and any additional cleanup needed
    true
  end

  def cleanup_file_storage
    # ActiveStorage will handle file cleanup automatically
    # This is for any additional cleanup if needed
    Rails.logger.info "Cleaned up file storage for document #{filename}"
    true
  end
end
