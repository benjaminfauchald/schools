class Transcript < ApplicationRecord
  belongs_to :place
  has_many :transcript_segments, dependent: :destroy
  
  # Neighbor gem for vector operations
  # Conditionally load has_neighbors to prevent errors during initialization
  begin
    has_neighbors :embedding if defined?(Neighbor)
  rescue => e
    Rails.logger.warn "Neighbor gem not properly loaded: #{e.message}"
  end
  
  # Validations
  validates :video_title, presence: true
  validates :youtube_video_id, uniqueness: { scope: :place_id }, allow_blank: true
  validates :primary_language, presence: true
  
  # Scopes
  scope :processed, -> { where.not(processed_at: nil) }
  scope :unprocessed, -> { where(processed_at: nil) }
  scope :with_embeddings, -> { where.not(embedding: nil) }
  scope :for_place, ->(place_id) { where(place_id: place_id) }
  
  # Vector similarity search with place_id isolation
  def self.similar_to(embedding, place_id, limit = 10)
    where(place_id: place_id)
      .where.not(embedding: nil)
      .nearest_neighbors(:embedding, embedding, distance: "cosine")
      .limit(limit)
  end
  
  # Generate embedding after creating full transcript text
  after_update :generate_embedding, if: :saved_change_to_full_transcript_text?
  
  # Extract full text from segments if not provided
  def extract_full_text_from_segments
    return if transcript_segments.empty?
    
    full_text = transcript_segments.order(:sequence_number).pluck(:text).join(' ')
    update_column(:full_transcript_text, full_text) if full_transcript_text.blank?
  end
  
  # Mark as processed
  def mark_as_processed!
    update!(processed_at: Time.current)
  end
  
  # Check if transcript has been processed
  def processed?
    processed_at.present?
  end
  
  # Get duration in human readable format
  def duration_formatted
    return 'Unknown duration' if total_duration_ms.blank?
    
    seconds = total_duration_ms / 1000
    minutes = seconds / 60
    hours = minutes / 60
    
    if hours > 0
      "#{hours}h #{minutes % 60}m"
    else
      "#{minutes}m #{seconds % 60}s"
    end
  end
  
  private
  
  def generate_embedding
    return if full_transcript_text.blank?
    
    GenerateEmbeddingJob.perform_later(self)
  end
end
