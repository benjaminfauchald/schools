# Event model manages scheduled events for places like open days, tours, special programs
# Supports any place type - schools, restaurants, hospitals, etc.
class Event < ApplicationRecord
  belongs_to :place

  validates :title, presence: true
  validates :starts_at, presence: true
  validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true

  validate :ends_at_after_starts_at

  scope :upcoming, -> { where("starts_at > ?", Time.current) }
  scope :past, -> { where("starts_at < ?", Time.current) }
  scope :current, -> { where("starts_at <= ? AND (ends_at IS NULL OR ends_at > ?)", Time.current, Time.current) }
  scope :ongoing, -> { current }
  scope :today, -> { where(starts_at: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :this_week, -> { where(starts_at: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :this_month, -> { where(starts_at: Date.current.beginning_of_month..Date.current.end_of_month) }
  scope :ordered, -> { order(:starts_at) }

  # Check if event is currently happening
  def happening_now?
    starts_at <= Time.current && (ends_at.nil? || ends_at > Time.current)
  end

  # Check if event is upcoming
  def upcoming?
    starts_at > Time.current
  end

  # Check if event has ended
  def past?
    ends_at ? ends_at < Time.current : starts_at < Time.current
  end

  # Get duration in minutes
  def duration_minutes
    return nil unless ends_at
    ((ends_at - starts_at) / 60).to_i
  end

  # Get duration as human readable string
  def duration_display
    return "Duration not specified" unless ends_at

    minutes = duration_minutes
    hours = minutes / 60
    remaining_minutes = minutes % 60

    if hours > 0 && remaining_minutes > 0
      "#{hours}h #{remaining_minutes}m"
    elsif hours > 0
      "#{hours}h"
    else
      "#{remaining_minutes}m"
    end
  end

  # Get time range as display string
  def time_range_display
    start_str = starts_at.strftime("%l:%M %p").strip

    if ends_at
      end_str = ends_at.strftime("%l:%M %p").strip
      same_day = starts_at.to_date == ends_at.to_date

      if same_day
        "#{start_str} - #{end_str}"
      else
        "#{starts_at.strftime('%b %d, %l:%M %p').strip} - #{ends_at.strftime('%b %d, %l:%M %p').strip}"
      end
    else
      start_str
    end
  end

  # Get date range as display string
  def date_range_display
    start_date = starts_at.strftime("%B %d, %Y")

    if ends_at && starts_at.to_date != ends_at.to_date
      end_date = ends_at.strftime("%B %d, %Y")
      "#{start_date} - #{end_date}"
    else
      start_date
    end
  end

  # Get full event time display
  def full_time_display
    "#{date_range_display} at #{time_range_display}"
  end

  # Days until event starts
  def days_until
    return 0 if past?
    ((starts_at.to_date - Date.current).to_i)
  end

  # Get status for display
  def status_display
    if happening_now?
      "Happening Now"
    elsif upcoming?
      days = days_until
      case days
      when 0
        "Today"
      when 1
        "Tomorrow"
      when 2..7
        "In #{days} days"
      else
        "Upcoming"
      end
    else
      "Past"
    end
  end

  private

  def ends_at_after_starts_at
    return unless starts_at && ends_at

    if ends_at <= starts_at
      errors.add(:ends_at, "must be after start time")
    end
  end
end
