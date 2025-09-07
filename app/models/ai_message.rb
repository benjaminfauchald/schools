# AI Message model for individual messages within AI conversations
# Supports user messages, assistant responses, and source attribution for RAG
class AiMessage < ApplicationRecord
  belongs_to :ai_conversation

  validates :ai_conversation, presence: true
  validates :role, presence: true, inclusion: { in: %w[user assistant] }
  validates :content, presence: true
  validates :message_type, inclusion: { in: %w[text suggested_question data_analysis] }

  enum :role, {
    user: "user",
    assistant: "assistant"
  }

  enum :message_type, {
    text: "text",
    suggested_question: "suggested_question",
    data_analysis: "data_analysis"
  }

  scope :recent, -> { order(:created_at) }
  scope :by_role, ->(role) { where(role: role) }
  scope :with_sources, -> { where.not(source_references: [ nil, [], {} ]) }
  scope :by_conversation, ->(conversation_id) { where(ai_conversation_id: conversation_id) }

  # Get the school this message belongs to (through conversation)
  def school
    ai_conversation.school
  end

  # Get the user this message belongs to (through conversation)
  def user
    ai_conversation.user
  end

  # Check if message has source references
  def has_sources?
    source_references.present? && !source_references.empty?
  end

  # Get formatted source references for display
  def formatted_sources
    return [] unless has_sources?

    sources = []
    source_references.each do |source|
      case source["type"]
      when "document"
        sources << format_document_source(source)
      when "transcript", "transcript_segment"
        sources << format_transcript_source(source)
      when "school_data"
        sources << format_school_data_source(source)
      when "place_data"
        sources << format_place_data_source(source)
      else
        sources << format_generic_source(source)
      end
    end

    sources.compact
  end

  # Check if this is a user message
  def user_message?
    role == "user"
  end

  # Check if this is an assistant message
  def assistant_message?
    role == "assistant"
  end

  # Get message age for display
  def age_display
    time_ago = Time.current - created_at

    case time_ago
    when 0..1.minute
      "Just now"
    when 1.minute..1.hour
      "#{(time_ago / 1.minute).to_i}m ago"
    when 1.hour..1.day
      "#{(time_ago / 1.hour).to_i}h ago"
    when 1.day..1.week
      "#{(time_ago / 1.day).to_i}d ago"
    else
      created_at.strftime("%b %d, %Y")
    end
  end

  # Export message data for AI context
  def ai_context_data
    {
      id: id,
      role: role,
      content: content,
      message_type: message_type,
      created_at: created_at.iso8601,
      has_sources: has_sources?,
      source_count: has_sources? ? source_references.length : 0,
      metadata: metadata
    }
  end

  # Get message content truncated for preview
  def content_preview(length = 100)
    return content if content.length <= length
    content.truncate(length, omission: "...")
  end

  # Check if message content contains specific keywords
  def mentions?(keywords)
    return false if content.blank? || keywords.blank?

    keywords = [ keywords ] unless keywords.is_a?(Array)
    content_lower = content.downcase

    keywords.any? { |keyword| content_lower.include?(keyword.downcase) }
  end

  # Get next message in conversation
  def next_message
    ai_conversation.ai_messages
                   .where("created_at > ?", created_at)
                   .order(:created_at)
                   .first
  end

  # Get previous message in conversation
  def previous_message
    ai_conversation.ai_messages
                   .where("created_at < ?", created_at)
                   .order(:created_at)
                   .last
  end

  # Check if this message can be edited (only recent user messages)
  def editable?
    user_message? && created_at > 5.minutes.ago
  end

  # Get source statistics
  def source_statistics
    return {} unless has_sources?

    stats = source_references.group_by { |ref| ref["type"] }
                             .transform_values(&:count)

    {
      total_sources: source_references.count,
      by_type: stats,
      has_documents: stats["document"].to_i > 0,
      has_transcripts: (stats["transcript"].to_i + stats["transcript_segment"].to_i) > 0,
      has_school_data: stats["school_data"].to_i > 0,
      has_place_data: stats["place_data"].to_i > 0
    }
  end

  # Class methods for analysis and reporting
  def self.conversation_flow(conversation_id)
    where(ai_conversation_id: conversation_id)
      .order(:created_at)
      .pluck(:role, :content, :created_at)
  end

  def self.messages_with_sources
    where.not(source_references: [ nil, [], {} ])
  end

  def self.by_message_type_stats
    group(:message_type).count
  end

  def self.source_usage_stats
    messages_with_sources.map(&:source_statistics)
                         .reduce({}) do |acc, stats|
                           acc[:total_sources] = (acc[:total_sources] || 0) + stats[:total_sources]
                           stats[:by_type].each do |type, count|
                             acc[type] = (acc[type] || 0) + count
                           end
                           acc
                         end
  end

  private

  def format_document_source(source)
    {
      "type" => "Document",
      "title" => source["title"] || source["filename"] || "Unknown Document",
      "description" => source["description"] || "PDF, Word, or other document",
      "url" => source["url"],
      "icon" => "📄"
    }
  end

  def format_transcript_source(source)
    title = source["video_title"] || "Video #{source['video_id']}"
    if source["segment_index"]
      title += " (#{format_time(source['start_time'])})"
    end

    {
      "type" => "Video Transcript",
      "title" => title,
      "description" => source["text"]&.truncate(100) || "Video transcript content",
      "url" => source["youtube_url"],
      "icon" => "🎥"
    }
  end

  def format_school_data_source(source)
    {
      "type" => "School Information",
      "title" => source["field_name"] || "School Data",
      "description" => source["description"] || "Information from school profile",
      "url" => nil,
      "icon" => "🏫"
    }
  end

  def format_place_data_source(source)
    {
      "type" => "Location Data",
      "title" => source["field_name"] || "Place Data",
      "description" => source["description"] || "Information from Google Places",
      "url" => source["google_maps_url"],
      "icon" => "📍"
    }
  end

  def format_generic_source(source)
    {
      "type" => source["type"]&.humanize || "Source",
      "title" => source["title"] || "Unknown Source",
      "description" => source["description"] || "Reference information",
      "url" => source["url"],
      "icon" => "📋"
    }
  end

  def format_time(seconds)
    return "0:00" unless seconds

    minutes = (seconds / 60).floor
    secs = (seconds % 60).floor
    "#{minutes}:#{secs.to_s.rjust(2, '0')}"
  end
end
