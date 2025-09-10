class TempClaim < ApplicationRecord
  belongs_to :school

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[pending_registration registered expired] }
  validates :ip_address, presence: true
  validates :expires_at, presence: true

  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }
  scope :pending_registration, -> { where(status: "pending_registration") }
  scope :registered, -> { where(status: "registered") }
  scope :stale, ->(days = 30) { where("created_at < ?", days.days.ago) }
  scope :old_registered, ->(days = 7) { registered.where("updated_at < ?", days.days.ago) }

  before_validation :generate_token, on: :create
  before_validation :set_expiry, on: :create

  def expired?
    expires_at <= Time.current
  end

  def active?
    !expired?
  end

  def pending_registration?
    status == "pending_registration"
  end

  def registered?
    status == "registered"
  end

  def mark_as_registered!
    update!(status: "registered")
  end

  def mark_as_expired!
    update!(status: "expired")
  end

  # Clean up expired claims
  def self.cleanup_expired!
    expired.update_all(status: "expired")
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiry
    # Claims expire after 24 hours
    self.expires_at ||= 24.hours.from_now
  end
end
