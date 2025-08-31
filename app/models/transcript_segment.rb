class TranscriptSegment < ApplicationRecord
  belongs_to :transcript
  
  # Neighbor gem for vector operations
  # Conditionally load has_neighbors to prevent errors during initialization
  begin
    has_neighbors :embedding if defined?(Neighbor)
  rescue => e
    Rails.logger.warn "Neighbor gem not properly loaded: #{e.message}"
  end
  
  # Validations
  validates :text, presence: true
  validates :offset_ms, :duration_ms, :sequence_number, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :sequence_number, uniqueness: { scope: :transcript_id }
  
  # Scopes
  scope :ordered, -> { order(:sequence_number) }
  scope :with_embeddings, -> { where.not(embedding: nil) }
  
  # Vector similarity search with place_id isolation
  def self.similar_to(embedding, place_id, limit = 10)
    joins(:transcript)
      .where(transcripts: { place_id: place_id })
      .where.not(embedding: nil)
      .nearest_neighbors(:embedding, embedding, distance: "cosine")
      .limit(limit)
  end
  
  # Generate embedding after creation
  after_create :generate_embedding
  after_update :generate_embedding, if: :saved_change_to_text?
  
  # Computed end time
  def end_time_ms
    offset_ms + duration_ms
  end
  
  # Get timestamp in human readable format
  def timestamp_formatted
    seconds = offset_ms / 1000
    minutes = seconds / 60
    hours = minutes / 60
    
    if hours > 0
      sprintf("%d:%02d:%02d", hours, minutes % 60, seconds % 60)
    else
      sprintf("%d:%02d", minutes, seconds % 60)
    end
  end
  
  # Get duration in human readable format
  def duration_formatted
    seconds = duration_ms / 1000
    if seconds < 60
      "#{seconds}s"
    else
      minutes = seconds / 60
      "#{minutes}m #{seconds % 60}s"
    end
  end
  
  private
  
  def generate_embedding
    return if text.blank?
    
    GenerateEmbeddingJob.perform_later(self)
  end
end
