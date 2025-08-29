class MagicLinkToken < ApplicationRecord
  belongs_to :user
  
  validates :token, presence: true, uniqueness: true
  validates :purpose, presence: true
  validates :expires_at, presence: true
  
  scope :active, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  
  before_validation :generate_token, on: :create
  before_validation :set_expiry, on: :create
  
  def expired?
    expires_at <= Time.current
  end
  
  def active?
    !expired? && !used_at.present?
  end
  
  def mark_as_used!
    update!(used_at: Time.current)
  end
  
  # Generate a magic link token for dashboard access
  def self.create_dashboard_token(user, expires_in: 48.hours)
    create!(
      user: user,
      purpose: 'dashboard_access',
      expires_at: expires_in.from_now
    )
  end
  
  # Clean up expired tokens
  def self.cleanup_expired!
    expired.delete_all
  end
  
  private
  
  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end
  
  def set_expiry
    self.expires_at ||= 48.hours.from_now
  end
end