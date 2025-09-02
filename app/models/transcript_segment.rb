# TranscriptSegment model for individual segments of video transcripts
# Enables granular search and context retrieval for AI RAG functionality
class TranscriptSegment < ApplicationRecord
  belongs_to :transcript
  
  validates :transcript, presence: true
  validates :segment_index, presence: true, uniqueness: { scope: :transcript_id }
  validates :text, presence: true
  
  scope :ordered, -> { order(:segment_index) }
  scope :by_speaker, ->(speaker) { where(speaker: speaker) if speaker.present? }
  scope :by_time_range, ->(start_time, end_time) { 
    where("start_time >= ? AND end_time <= ?", start_time, end_time) 
  }
  scope :with_confidence_above, ->(threshold) { 
    where("confidence >= ?", threshold) if threshold.present?
  }
  
  # Get segment duration
  def duration
    return nil unless start_time.present? && end_time.present?
    end_time - start_time
  end
  
  # Get duration in human readable format
  def duration_display
    dur = duration
    return 'Unknown' unless dur
    
    if dur < 60
      "#{dur.round(1)}s"
    else
      minutes = (dur / 60).floor
      seconds = (dur % 60).round(1)
      "#{minutes}m #{seconds}s"
    end
  end
  
  # Get formatted time range for display
  def time_range_display
    return 'Unknown time' unless start_time.present? && end_time.present?
    
    start_formatted = format_seconds(start_time)
    end_formatted = format_seconds(end_time)
    "#{start_formatted} - #{end_formatted}"
  end
  
  # Get YouTube URL with timestamp
  def youtube_url_with_timestamp
    base_url = transcript.youtube_url
    return base_url unless start_time.present?
    
    timestamp = start_time.to_i
    "#{base_url}&t=#{timestamp}s"
  end
  
  # Search within segment text
  def matches_query?(query)
    return false if query.blank?
    text.downcase.include?(query.downcase)
  end
  
  # Get embedding as array for vector operations
  def embedding_vector
    return nil unless embedding.present?
    
    begin
      JSON.parse(embedding)
    rescue JSON::ParserError
      nil
    end
  end
  
  # Set embedding from array
  def embedding_vector=(vector)
    self.embedding = vector.to_json if vector.is_a?(Array)
  end
  
  # Check if segment has embedding for RAG
  def has_embedding?
    embedding.present?
  end
  
  # Export segment data for AI context
  def ai_context_data
    {
      id: id,
      segment_index: segment_index,
      text: text,
      start_time: start_time,
      end_time: end_time,
      duration: duration,
      speaker: speaker,
      confidence: confidence,
      youtube_url: youtube_url_with_timestamp,
      transcript_id: transcript_id,
      video_title: transcript.video_title
    }
  end
  
  # Get context around this segment (previous and next segments)
  def surrounding_context(before: 1, after: 1)
    segments = transcript.transcript_segments.ordered
    current_index = segments.index(self)
    return [] unless current_index
    
    start_index = [current_index - before, 0].max
    end_index = [current_index + after, segments.count - 1].min
    
    segments[start_index..end_index]
  end
  
  # Get the next segment
  def next_segment
    transcript.transcript_segments
              .where("segment_index > ?", segment_index)
              .order(:segment_index)
              .first
  end
  
  # Get the previous segment
  def previous_segment
    transcript.transcript_segments
              .where("segment_index < ?", segment_index)
              .order(:segment_index)
              .last
  end
  
  # Check if segment is likely to contain important information
  def likely_important?
    return false if text.blank?
    
    # Simple heuristics for importance
    important_patterns = [
      /\b(important|key|main|primary|essential|critical)\b/i,
      /\b(conclusion|summary|result|finding)\b/i,
      /\?\s*$/,  # Questions
      /\b(first|second|third|finally|lastly)\b/i,  # Enumeration
      /\b(however|but|although|despite)\b/i  # Contrasts
    ]
    
    important_patterns.any? { |pattern| text.match?(pattern) }
  end
  
  # Class methods for search and analysis
  def self.search_by_content(query, limit: 20)
    return none if query.blank?
    
    where("text ILIKE ?", "%#{query}%")
      .joins(:transcript)
      .where(transcripts: { status: 'completed' })
      .includes(:transcript)
      .ordered
      .limit(limit)
  end
  
  def self.by_transcript_ids(transcript_ids)
    joins(:transcript).where(transcripts: { id: transcript_ids })
  end
  
  def self.with_embeddings
    where.not(embedding: [nil, ''])
  end
  
  def self.find_similar_segments(query_embedding, limit: 10)
    # This would require pgvector extension for proper vector similarity
    # For now, return empty relation
    none
  end
  
  private
  
  def format_seconds(seconds)
    return '0:00' unless seconds
    
    minutes = (seconds / 60).floor
    secs = (seconds % 60).floor
    
    if minutes >= 60
      hours = (minutes / 60).floor
      mins = minutes % 60
      "#{hours}:#{mins.to_s.rjust(2, '0')}:#{secs.to_s.rjust(2, '0')}"
    else
      "#{minutes}:#{secs.to_s.rjust(2, '0')}"
    end
  end
end