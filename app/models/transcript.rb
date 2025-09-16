# Transcript model for YouTube video transcripts
# Stores full transcripts and their metadata for AI RAG functionality
class Transcript < ApplicationRecord
  belongs_to :place
  has_many :transcript_segments, dependent: :destroy

  validates :video_id, presence: true, uniqueness: { scope: :place_id }
  validates :place, presence: true

  enum :status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed",
    no_transcript: "no_transcript"
  }

  scope :processed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :pending_processing, -> { where(status: [ "pending", "processing" ]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_language, ->(lang) { where(language: lang) }
  scope :ai_enabled, -> { where(ai_enabled: true) }
  scope :ai_disabled, -> { where(ai_enabled: false) }
  scope :with_embeddings, -> { where.not(vector_embedding: nil) }
  scope :cleaned, -> { where.not(cleaned_transcript: nil) }
  scope :needs_cleaning, -> { where(cleaned_transcript: nil).where.not(full_transcript: [ nil, "" ]) }

  # Check if transcript has been successfully processed
  def processed?
    status == "completed" && full_transcript.present?
  end

  # Check if transcript is available for AI use
  def available_for_ai?
    processed? && ai_enabled?
  end

  # Check if transcript has segments
  def has_segments?
    transcript_segments.any?
  end

  # Get transcript duration in human readable format
  def duration_display
    return "Unknown duration" unless duration_seconds.present?

    hours = duration_seconds / 3600
    minutes = (duration_seconds % 3600) / 60
    seconds = duration_seconds % 60

    if hours > 0
      "#{hours}h #{minutes}m #{seconds}s"
    elsif minutes > 0
      "#{minutes}m #{seconds}s"
    else
      "#{seconds}s"
    end
  end

  # Get video URL from video_id
  def youtube_url
    return video_url if video_url.present?
    "https://www.youtube.com/watch?v=#{video_id}"
  end

  # Search transcript content
  def search_content(query)
    return [] if query.blank?

    segments = transcript_segments.where("text ILIKE ?", "%#{query}%")
    {
      transcript: self,
      segments: segments,
      matches: segments.count
    }
  end

  # Check if transcript has been cleaned by AI
  def cleaned?
    cleaned_transcript.present? && cleaned_at.present?
  end

  # Get the best available transcript content (cleaned first, then raw)
  def best_transcript_content
    cleaned_transcript.present? ? cleaned_transcript : full_transcript
  end

  # Check if transcript needs cleaning
  def needs_cleaning?
    processed? && ai_enabled? && full_transcript.present? && cleaned_transcript.blank?
  end

  # Check if transcript has embedding for RAG (now using pgvector)
  def has_embedding?
    vector_embedding.present?
  end

  # Get embedding vector for similarity search (pgvector format)
  def embedding_vector
    vector_embedding
  end

  # Check if embedding is up to date (generated recently)
  def embedding_up_to_date?(threshold: 30.days)
    embedding_generated_at.present? && embedding_generated_at > threshold.ago
  end

  # Check if transcript is ready for embedding (has cleaned content)
  def ready_for_embedding?
    cleaned? && !has_embedding?
  end

  # Legacy support for old embedding field (JSON format) - for migration
  def legacy_embedding_vector
    return nil unless embedding.present?

    begin
      JSON.parse(embedding)
    rescue JSON::ParserError
      nil
    end
  end

  # Export transcript data for AI context
  def ai_context_data
    {
      id: id,
      video_id: video_id,
      title: video_title,
      description: video_description,
      content: full_transcript,
      duration: duration_display,
      language: language,
      segments_count: transcript_segments.count,
      processed_at: processed_at&.iso8601
    }
  end

  # Processing status helpers
  def processing_failed?
    status == "failed"
  end

  def can_reprocess?
    processing_failed? || status == "completed"
  end

  # Mark as processing
  def mark_processing!
    update!(
      status: "processing",
      processing_error: nil,
      processed_at: Time.current
    )
  end

  # Mark as completed
  def mark_completed!(transcript_text, segments_data = [])
    update!(
      status: "completed",
      full_transcript: transcript_text,
      processing_error: nil,
      processed_at: Time.current
    )

    # Create transcript segments if provided
    if segments_data.present?
      segments_data.each_with_index do |segment_data, index|
        transcript_segments.create!(
          segment_index: index,
          text: segment_data[:text],
          start_time: segment_data[:start_time],
          end_time: segment_data[:end_time],
          speaker: segment_data[:speaker],
          confidence: segment_data[:confidence]
        )
      end
    end
  end

  # Mark as failed
  def mark_failed!(error_message)
    update!(
      status: "failed",
      processing_error: error_message,
      processed_at: Time.current
    )
  end

  # Mark as no transcript (for videos without speech/captions)
  def mark_no_transcript!(reason)
    update!(
      status: "no_transcript",
      processing_error: reason,
      processed_at: Time.current
    )
  end

  # Class methods for statistics and management
  def self.processing_stats
    {
      total: count,
      completed: where(status: "completed").count,
      processing: where(status: "processing").count,
      failed: where(status: "failed").count,
      pending: where(status: "pending").count,
      no_transcript: where(status: "no_transcript").count,
      with_embeddings: where.not(vector_embedding: nil).count
    }
  end

  def self.search_by_content(query, limit: 10)
    return none if query.blank?

    where("full_transcript ILIKE ? OR video_title ILIKE ?", "%#{query}%", "%#{query}%")
      .processed
      .limit(limit)
  end
end
