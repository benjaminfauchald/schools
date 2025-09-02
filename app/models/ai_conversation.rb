# AI Conversation model for managing chat sessions between school owners and AI
# Scoped to individual schools for data isolation and privacy
class AiConversation < ApplicationRecord
  belongs_to :school
  belongs_to :user
  has_many :ai_messages, dependent: :destroy
  
  validates :school, presence: true
  validates :user, presence: true
  
  enum :status, {
    active: 'active',
    archived: 'archived',
    suspended: 'suspended'
  }
  
  scope :recent, -> { order(last_message_at: :desc, created_at: :desc) }
  scope :for_school, ->(school_id) { where(school_id: school_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :with_recent_activity, -> { where('last_message_at > ?', 30.days.ago) }
  
  # Auto-generate conversation title from first user message
  before_create :set_default_title
  
  # Get the last message in the conversation
  def last_message
    ai_messages.order(:created_at).last
  end
  
  # Get the first user message (for title generation)
  def first_user_message
    ai_messages.where(role: 'user').order(:created_at).first
  end
  
  # Check if conversation has any messages
  def has_messages?
    ai_messages.exists?
  end
  
  # Get message count
  def message_count
    ai_messages.count
  end
  
  # Add a user message to the conversation
  def add_user_message(content, metadata = {})
    message = ai_messages.create!(
      role: 'user',
      content: content,
      metadata: metadata,
      message_type: 'text'
    )
    
    update_last_message_timestamp!
    update_title_if_needed!
    message
  end
  
  # Add an assistant message to the conversation
  def add_assistant_message(content, source_references = [], metadata = {})
    message = ai_messages.create!(
      role: 'assistant',
      content: content,
      source_references: source_references,
      metadata: metadata,
      message_type: 'text'
    )
    
    update_last_message_timestamp!
    message
  end
  
  # Add a suggested question message
  def add_suggested_question(content, metadata = {})
    ai_messages.create!(
      role: 'assistant',
      content: content,
      metadata: metadata,
      message_type: 'suggested_question'
    )
  end
  
  # Add a data analysis message
  def add_data_analysis(content, source_references = [], metadata = {})
    ai_messages.create!(
      role: 'assistant',
      content: content,
      source_references: source_references,
      metadata: metadata,
      message_type: 'data_analysis'
    )
  end
  
  # Get conversation context for AI (recent messages)
  def conversation_context(limit: 10)
    ai_messages.order(:created_at)
               .last(limit)
               .map(&:ai_context_data)
  end
  
  # Export conversation for analysis or backup
  def export_data
    {
      id: id,
      school_id: school_id,
      user_id: user_id,
      title: title,
      status: status,
      created_at: created_at.iso8601,
      last_message_at: last_message_at&.iso8601,
      message_count: message_count,
      messages: ai_messages.order(:created_at).map(&:ai_context_data)
    }
  end
  
  # Archive the conversation
  def archive!
    update!(status: 'archived')
  end
  
  # Reactivate archived conversation
  def reactivate!
    update!(status: 'active')
  end
  
  # Get conversation age in days
  def age_in_days
    return 0 unless created_at
    (Time.current - created_at) / 1.day
  end
  
  # Check if conversation is recent (less than 24 hours old)
  def recent?
    age_in_days < 1
  end
  
  # Check if user can access this conversation (ownership check)
  def accessible_by?(user)
    return false unless user
    
    # User must be the owner or have claims on the school
    self.user == user || school.school_claims.active.where(user: user).exists?
  end
  
  # Get conversation statistics
  def statistics
    messages = ai_messages.includes(:ai_conversation)
    
    {
      total_messages: messages.count,
      user_messages: messages.where(role: 'user').count,
      assistant_messages: messages.where(role: 'assistant').count,
      suggested_questions: messages.where(message_type: 'suggested_question').count,
      data_analyses: messages.where(message_type: 'data_analysis').count,
      first_message_at: messages.order(:created_at).first&.created_at,
      last_message_at: messages.order(:created_at).last&.created_at,
      unique_source_references: messages.where.not(source_references: [nil, [], {}])
                                        .pluck(:source_references)
                                        .flatten
                                        .uniq
                                        .count
    }
  end
  
  # Class methods
  def self.for_school_and_user(school_id, user_id)
    where(school_id: school_id, user_id: user_id)
  end
  
  def self.recent_activity
    joins(:ai_messages)
      .where(ai_messages: { created_at: 7.days.ago.. })
      .distinct
      .includes(:ai_messages, :school, :user)
  end
  
  def self.conversation_stats
    {
      total_conversations: count,
      active_conversations: active.count,
      archived_conversations: archived.count,
      conversations_with_messages: joins(:ai_messages).distinct.count,
      average_messages_per_conversation: joins(:ai_messages).count.to_f / count,
      conversations_last_30_days: where(created_at: 30.days.ago..).count
    }
  end
  
  private
  
  def set_default_title
    self.title ||= "Chat #{Time.current.strftime('%b %d, %Y')}"
  end
  
  def update_last_message_timestamp!
    update_column(:last_message_at, Time.current)
  end
  
  def update_title_if_needed!
    return unless title == "Chat #{created_at.strftime('%b %d, %Y')}" || title.blank?
    
    first_msg = first_user_message
    if first_msg && first_msg.content.present?
      # Use first 50 characters of first message as title
      new_title = first_msg.content.truncate(50, omission: '...')
      update_column(:title, new_title)
    end
  end
end