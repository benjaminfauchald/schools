class DocumentContent < ApplicationRecord
  belongs_to :place
  
  # Neighbor gem for vector operations
  has_neighbors :embedding
  
  # Active Storage for file uploads
  has_one_attached :file
  
  # Enums
  enum :content_type, {
    transcript: 'transcript',
    pdf_document: 'pdf_document', 
    text_document: 'text_document',
    uploaded_file: 'uploaded_file'
  }
  
  enum :processing_status, {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed'
  }
  
  # Validations
  validates :title, :content_type, presence: true
  validates :processing_status, inclusion: { in: processing_statuses.keys }
  
  # Scopes
  scope :for_place, ->(place_id) { where(place_id: place_id) }
  scope :with_embeddings, -> { where.not(embedding: nil) }
  
  # Vector similarity search with place_id isolation
  def self.similar_to(embedding, place_id, limit = 10)
    where(place_id: place_id)
      .where.not(embedding: nil)
      .nearest_neighbors(:embedding, embedding, distance: "cosine")
      .limit(limit)
  end
  
  # Generate embedding after text processing
  after_update :generate_embedding, if: :saved_change_to_processed_text?
  
  # Mark as completed
  def mark_as_completed!
    update!(
      processing_status: 'completed',
      metadata: metadata.merge(processed_at: Time.current.iso8601)
    )
  end
  
  # Mark as failed
  def mark_as_failed!(error_message = nil)
    error_data = { failed_at: Time.current.iso8601 }
    error_data[:error_message] = error_message if error_message.present?
    
    update!(
      processing_status: 'failed',
      metadata: metadata.merge(error_data)
    )
  end
  
  # Get file size if attached
  def file_size_formatted
    return 'No file' unless file.attached?
    
    bytes = file.byte_size
    units = ['B', 'KB', 'MB', 'GB']
    
    return "#{bytes} B" if bytes < 1024
    
    units.each_with_index do |unit, index|
      size = bytes / (1024.0 ** (index + 1))
      if size < 1024 || index == units.length - 1
        return "#{size.round(1)} #{unit}"
      end
    end
  end
  
  # Extract text content based on type
  def extract_text_content
    case content_type
    when 'pdf_document'
      extract_pdf_text
    when 'text_document', 'uploaded_file'
      extract_file_text
    else
      processed_text
    end
  end
  
  private
  
  def generate_embedding
    return if processed_text.blank?
    
    GenerateEmbeddingJob.perform_later(self)
  end
  
  def extract_pdf_text
    return unless file.attached? && file.content_type == 'application/pdf'
    
    # This would be implemented with a PDF parsing service
    # For now, return placeholder
    processed_text || 'PDF text extraction not implemented yet'
  end
  
  def extract_file_text
    return unless file.attached?
    
    if file.content_type.start_with?('text/')
      file.download
    else
      processed_text
    end
  end
end
