# TravelTime model caches commute times from various origins to places
# Supports multiple transportation modes and asynchronous computation for performance
class TravelTime < ApplicationRecord
  belongs_to :place
  
  validates :origin_hash, presence: true
  validates :mode, presence: true, inclusion: { in: %w[driving transit walking cycling] }
  validates :computed_at, presence: true
  validates :minutes, numericality: { greater_than: 0 }, allow_nil: true
  validates :origin_hash, uniqueness: { scope: [:place_id, :mode] }
  
  scope :by_mode, ->(mode) { where(mode: mode) }
  scope :recent, ->(hours = 24) { where('computed_at > ?', hours.hours.ago) }
  scope :stale, ->(hours = 24) { where('computed_at <= ?', hours.hours.ago) }
  scope :successful, -> { where.not(minutes: nil) }
  scope :failed, -> { where(minutes: nil) }
  
  # Check if travel time needs refresh (older than 24 hours)
  def stale?
    computed_at < 24.hours.ago
  end
  
  # Check if computation was successful
  def successful?
    minutes.present?
  end
  
  # Get travel time as human readable string
  def duration_display
    return 'Unable to calculate' unless minutes
    
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
  
  # Get transportation mode display
  def mode_display
    case mode
    when 'driving'
      '🚗 Driving'
    when 'transit'
      '🚌 Public Transit'
    when 'walking' 
      '🚶 Walking'
    when 'cycling'
      '🚴 Cycling'
    else
      mode.humanize
    end
  end
  
  # Get full display string
  def full_display
    "#{duration_display} #{mode_display.downcase}"
  end
  
  # Age of this computation in hours
  def age_hours
    ((Time.current - computed_at) / 1.hour).round(1)
  end
  
  # Check if this is a reasonable travel time
  def reasonable?
    return false unless minutes
    
    case mode
    when 'walking'
      minutes <= 120 # 2 hours max walking
    when 'cycling'
      minutes <= 90  # 1.5 hours max cycling
    when 'driving'
      minutes <= 180 # 3 hours max driving
    when 'transit'
      minutes <= 240 # 4 hours max transit
    else
      true
    end
  end
  
  # Get travel time category
  def distance_category
    return 'Unknown' unless minutes
    
    case minutes
    when 0..15
      'Very Close'
    when 16..30
      'Close'
    when 31..60
      'Moderate'
    when 61..90
      'Far'
    else
      'Very Far'
    end
  end
  
  # Class method to generate origin hash from coordinates
  def self.generate_origin_hash(lat, lng, precision: 3)
    # Round to specified precision to group nearby origins
    rounded_lat = lat.round(precision)
    rounded_lng = lng.round(precision)
    "#{rounded_lat},#{rounded_lng}"
  end
  
  # Class method to find or create travel time
  def self.find_or_compute(place, origin_lat, origin_lng, mode: 'driving', precision: 3)
    origin_hash = generate_origin_hash(origin_lat, origin_lng, precision: precision)
    
    travel_time = find_by(place: place, origin_hash: origin_hash, mode: mode)
    
    if travel_time&.stale? || travel_time.nil?
      # Queue for background computation
      # ComputeTravelTimeJob.perform_async(place.id, origin_hash, mode)
      travel_time ||= create!(
        place: place,
        origin_hash: origin_hash,
        mode: mode,
        computed_at: Time.current,
        minutes: nil # Will be filled by background job
      )
    end
    
    travel_time
  end
end