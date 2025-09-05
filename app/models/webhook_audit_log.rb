class WebhookAuditLog < ApplicationRecord
  belongs_to :user, optional: true # User may be deleted after webhook processing

  validates :webhook_type, presence: true, inclusion: { in: %w[deletion deauthorization] }
  validates :facebook_user_id, presence: true
  validates :payload, presence: true
  validates :status, inclusion: { in: %w[processed failed invalid] }

  scope :deletions, -> { where(webhook_type: 'deletion') }
  scope :deauthorizations, -> { where(webhook_type: 'deauthorization') }
  scope :successful, -> { where(status: 'processed') }
  scope :failed, -> { where(status: 'failed') }
  scope :recent, -> { order(processed_at: :desc) }

  def self.log_deletion(facebook_user_id:, user: nil, payload:, status: 'processed', error_message: nil)
    create!(
      webhook_type: 'deletion',
      facebook_user_id: facebook_user_id,
      user: user,
      payload: payload,
      status: status,
      error_message: error_message,
      processed_at: Time.current
    )
  end

  def self.log_deauthorization(facebook_user_id:, user: nil, payload:, status: 'processed', error_message: nil)
    create!(
      webhook_type: 'deauthorization',
      facebook_user_id: facebook_user_id,
      user: user,
      payload: payload,
      status: status,
      error_message: error_message,
      processed_at: Time.current
    )
  end

  def successful?
    status == 'processed'
  end

  def failed?
    status == 'failed'
  end

  def deletion?
    webhook_type == 'deletion'
  end

  def deauthorization?
    webhook_type == 'deauthorization'
  end
end