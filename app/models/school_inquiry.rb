class SchoolInquiry < ApplicationRecord
  belongs_to :school
  belongs_to :user, optional: true

  validates :name, presence: true, length: { maximum: 100 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :message, presence: true, length: { maximum: 2000 }
  validates :children_count, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 20 }
  validates :phone, length: { maximum: 20 }, allow_blank: true
  validates :status, inclusion: { in: %w[new read responded closed] }

  enum :status, {
    new: "new",
    read: "read",
    responded: "responded",
    closed: "closed"
  }, prefix: true

  scope :recent, -> { order(created_at: :desc) }
  scope :unread, -> { where(read_at: nil) }

  before_validation :set_default_status, on: :create

  def mark_as_read!
    update!(status: "read", read_at: Time.current) if status_new?
  end

  def display_phone
    phone.presence || "Not provided"
  end

  def days_ago
    ((Time.current - created_at) / 1.day).round
  end

  def lead_source
    if user&.provider == "facebook"
      "Facebook: #{user.facebook_name}"
    elsif user
      "Registered User: #{user.email}"
    else
      "Direct (Legacy)"
    end
  end

  private

  def set_default_status
    self.status ||= "new"
  end
end
