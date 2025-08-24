class Point < ApplicationRecord
  validates :osm_id, presence: true, uniqueness: true
  validates :lat, :lon, presence: true, numericality: true
  
  scope :schools, -> { where(amenity: 'school') }
  scope :with_names, -> { where.not(name: [nil, '']) }
  scope :with_amenity, -> { where.not(amenity: [nil, '']) }
  
  # Association with Places
  has_many :places, dependent: :destroy
  has_one :primary_place, -> { order(:created_at) }, class_name: 'Place'
  
  def coordinates
    [lat, lon]
  end
  
  def named?
    name.present?
  end
  
  def has_amenity?
    amenity.present?
  end
  
  def google_place_data
    primary_place
  end
end
